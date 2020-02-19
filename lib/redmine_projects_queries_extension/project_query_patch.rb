require_dependency 'project_query'

class ProjectQuery < Query

  def self.has_organizations_plugin?
    Redmine::Plugin.installed?(:redmine_organizations)
  end

  def self.has_limited_visibility_plugin?
    Redmine::Plugin.installed?(:redmine_limited_visibility)
  end

  self.available_columns << QueryColumn.new(:updated_on, :sortable => "#{Project.table_name}.updated_on", :default_order => 'desc') unless self.available_columns.select {|c| c.name == :updated_on}.present?
  self.available_columns << QueryColumn.new(:activity, :groupable => false, :sortable => ProjectSummary.sql_activity_records) unless self.available_columns.select {|c| c.name == :activity}.present?
  self.available_columns << QueryColumn.new(:issues, :sortable => false) unless self.available_columns.select {|c| c.name == :issues}.present?
  self.available_columns << QueryColumn.new(:role, :sortable => false) unless self.available_columns.select {|c| c.name == :role}.present?
  self.available_columns << QueryColumn.new(:members, :sortable => false) unless self.available_columns.select {|c| c.name == :members}.present?
  self.available_columns << QueryColumn.new(:users, :sortable => false) unless self.available_columns.select {|c| c.name == :users}.present?
  self.available_columns << QueryColumn.new(:description)
  self.available_columns << QueryColumn.new(:organizations, :sortable => false, :default_order => 'asc') if self.has_organizations_plugin?
end

module PluginProjectsQueriesExtension
  module ProjectQueryPatch

    def initialize_available_filters
      super

      member_values = []
      member_values << ["<< #{l(:label_me)} >>", "me"] if User.current.logged?
      member_values += all_users.collect {|s| [s.name, s.id.to_s]}
      add_available_filter("member_id",
                           :type => :list, :values => member_values
      ) unless member_values.empty?

      add_available_filter "updated_on", :type => :date_past

      if self.class.has_organizations_plugin?
        directions_values = Organization.select("name, id").where('direction = ?', true).order("name")
        add_available_filter("organizations", :type => :list, :values => directions_values.collect {|s| [s.name, s.id.to_s]})
        organizations_values = Organization.all.collect {|s| [s.fullname, s.id.to_s]}.sort_by {|v| v.first}
        add_available_filter("organization", :type => :list, :values => organizations_values)
      end

    end

    def available_display_types
      ['list', 'board']
    end

    def available_columns
      return @available_columns if @available_columns
      @available_columns = super
      if self.class.has_organizations_plugin?
        # role display is NOT strictly related to organizations plugin but for
        # now the plugin only knows how to display these columns if the
        # organizations plugin is present => we display organizations names in the column...
        @available_columns += Role.where("builtin = 0").order("position asc").all.collect {|role| QueryRoleColumn.new(role)}
        if self.class.has_limited_visibility_plugin?
          @available_columns += Function.order("position asc").all.collect {|function| QueryFunctionColumn.new(function)}
        end
      end
      @available_columns
    end

    # Returns a representation of the available filters for JSON serialization
    def available_filters_as_json
      json = {}
      available_filters.each do |field, filter|
        options = {:type => filter[:type], :name => filter[:name]}
        options[:name] = l("field_project") if field == "id"
        options[:name] = l("label_member") if field == "member_id"
        options[:remote] = true if filter.remote
        if has_filter?(field) || !filter.remote
          options[:values] = filter.values
          if options[:values] && values_for(field)
            missing = Array(values_for(field)).select(&:present?) - options[:values].map(&:last)
            if missing.any? && respond_to?(method = "find_#{field}_filter_values")
              options[:values] += send(method, missing)
            end
          end
        end
        json[field] = options.stringify_keys
      end
      json
    end

    def all_users
      timestamp = Member.maximum(:created_on)
      Rails.cache.fetch ['all-users', timestamp.to_i].join('/') do
        principals = []
        principals += Principal.active.joins(:members).where("#{Member.table_name}.project_id IN (SELECT id FROM #{Project.table_name})").uniq
        principals.sort!
        principals.select {|p| p.is_a?(User)}
      end
    end

    def sql_for_member_id_field(field, operator, value)
      if value.delete('me')
        value.push User.current.id.to_s
      end
      member_table = Member.table_name
      project_table = Project.table_name
      #return only the projects including all the selected members
      "#{project_table}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT #{member_table}.project_id FROM #{member_table} " +
          "JOIN #{project_table} ON #{member_table}.project_id = #{project_table}.id AND " +
          sql_for_field(field, '=', value, member_table, 'user_id') +
          "GROUP BY #{member_table}.project_id HAVING count(#{member_table}.project_id) = #{value.size}" + ') '
    end

    def sql_for_organizations_field(field, operator, value)

      organization_table = Organization.table_name
      membership_table = Member.table_name

      "#{Project.table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT project_id FROM #{membership_table}
                                                                        INNER JOIN users ON users.id = #{membership_table}.user_id AND users.type IN ('User', 'AnonymousUser') AND users.status != #{Principal::STATUS_LOCKED}
                                                                        WHERE organization_id IN
                                                                        (WITH RECURSIVE rec_tree(parent_id, id, name, direction, depth) AS (
                                                                        SELECT t.parent_id, t.id, t.name, t.direction, 1
                                                                        FROM #{organization_table} t
                                                                        WHERE #{sql_for_field(field, '=', value, 't', 'id')}
                                                                        UNION ALL
                                                                        SELECT t.parent_id, t.id, t.name, rt.direction, rt.depth + 1
                                                                        FROM #{organization_table} t, rec_tree rt
                                                                        WHERE t.parent_id = rt.id
                                                                      )
                                                                      SELECT id FROM rec_tree))"
    end

    def sql_for_organization_field(field, operator, value)

      membership_table = Member.table_name

      "#{Project.table_name}.id #{ operator == '=' ? 'IN' : 'NOT IN' } (SELECT DISTINCT project_id FROM #{membership_table}
                                                                          INNER JOIN users ON users.id = #{membership_table}.user_id AND users.type IN ('User', 'AnonymousUser')
                                                                          WHERE #{sql_for_field(field, '=', value, User.table_name, 'organization_id')}
                                                                        )"
    end

  end
end

ProjectQuery.prepend PluginProjectsQueriesExtension::ProjectQueryPatch

class QueryRoleColumn < QueryColumn
  def initialize(role)
    self.name = "role_#{role.id}".to_sym
    self.sortable = false
    self.groupable = false
    @inline = true
    @role = role
  end

  def caption
    @role.name
  end

  def role
    @role
  end
end

class QueryFunctionColumn < QueryColumn
  def initialize(function)
    self.name = "function_#{function.id}".to_sym
    self.sortable = false
    self.groupable = false
    @inline = true
    @function = function
  end

  def caption
    @function.name
  end

  def role
    @function
  end
end
