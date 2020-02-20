require_dependency 'projects_controller'
require_dependency 'project'

class ProjectsController

  before_action :preload_memberships, only: [:index]

  skip_before_action :find_project, :only => [:get_mail_addresses]
  skip_before_action :authorize, :only => [:get_mail_addresses]

  def preload_memberships
    #pre-load current user's memberships
    @memberships = User.current.memberships.inject({}) do |memo, membership|
      memo[membership.project_id] = membership.roles
      memo
    end
  end

  def members_map
    @members_map ||= Rails.cache.fetch("projects-members-#{Member.maximum("created_on").to_i}") do
      user_names_map = {}
      @query.all_users.each do |u|
        user_names_map[u.id] = u.name
      end
      members_by_project_map = {}
      @entries.each do |p|
        members = p.send("members")
        members_by_project_map[p.id] = members.collect {|m| "#{user_names_map[m.user_id]}"}.compact.join(', ').html_safe
      end
      members_by_project_map
    end
  end

  helper_method :members_map

  def organizations_map
    cache_strategy = ['all-organizations', Member.maximum("created_on").to_i, Organization.maximum("updated_at").to_i, 2].join('/')
    @organizations_map ||= Rails.cache.fetch cache_strategy do
      orgas_fullnames = {}
      Organization.all.each do |o|
        orgas_fullnames[o.id] = o.fullname
      end

      sql = Organization.select("organizations.id, project_id, role_id").joins(:users => {:members => :member_roles}).order("project_id, role_id, organizations.id").group("project_id, role_id, organizations.id").to_sql
      array = ActiveRecord::Base.connection.execute(sql)
      map = {}
      array.each do |record|
        unless map[record["project_id"]]
          map[record["project_id"]] = {}
        end
        unless map[record["project_id"]][record["role_id"]]
          map[record["project_id"]][record["role_id"]] = []
        end
        map[record["project_id"]][record["role_id"]] << orgas_fullnames[record["id"]]
      end

      if Redmine::Plugin.installed?(:redmine_limited_visibility)
        sql = Organization.select("organizations.id, project_id, function_id").joins(:users => {:members => :member_functions}).order("project_id, function_id, organizations.id").group("project_id, function_id, organizations.id").to_sql
        array = ActiveRecord::Base.connection.execute(sql)
        array.each do |record|
          unless map[record["project_id"]]
            map[record["project_id"]] = {}
          end
          unless map[record["project_id"]]["function_#{record["function_id"]}"]
            map[record["project_id"]]["function_#{record["function_id"]}"] = []
          end
          map[record["project_id"]]["function_#{record["function_id"]}"] << orgas_fullnames[record["id"]]
        end
      end

      map
    end
  end

  helper_method :organizations_map

  def directions_map
    @directions_map ||= Rails.cache.fetch ['all-directions', Member.maximum("created_on").to_i, Organization.maximum("updated_at").to_i].join('/') do
      map = {}
      @entries.each do |p|
        orgas = p.send("organizations")
        directions = []
        orgas.each do |o|
          directions << o.direction_organization.name
        end
        directions.uniq!
        if (directions.size > 1)
          directions = directions - ["CPII"]
        end
        map[p.id] = directions.join(', ').html_safe
      end
      map
    end
  end

  helper_method :directions_map

  def get_mail_addresses
    retrieve_project_query
    @projects = project_scope
    # remove_hidden_projects
    if params['role'].present?
      filename = "emails-#{Role.find(params['role']).join("-")}.csv"
    else
      filename = "emails.csv"
    end
    send_data query_to_mail_addresses(@projects, params), :type => 'text/csv', :filename => filename
  end

  def query_to_mail_addresses(projects, options = {})
    encoding = l(:general_csv_encoding)

    all_users = []
    # TODO This code seems very slow, we should refactor it
    projects.each do |project|
      if options['role'].blank? && options['function'].blank?
        all_users = all_users | project.users
      end
      if options['role'].present?
        roles = Role.find(options['role'].split(','))
        roles.each do |role|
          all_users = all_users | project.users_by_role[role] if project.users_by_role[role]
        end
      end
      if options['function'].present?
        functions = Function.find(options['function'].split(','))
        functions.each do |function|
          all_users = all_users | project.users_by_function[function] if project.users_by_function[function]
        end
      end
    end
    all_users.sort! {|a, b| a.lastname.downcase <=> b.lastname.downcase}

    Redmine::Export::CSV.generate do |csv|
      # csv lines
      all_users.in_groups_of(50, false).each do |group| # TODO make it customizable in plugin settings
        # csv line
        csv << group.collect {|u| Redmine::CodesetUtil.from_utf8(u.mail, encoding)}
      end
    end
  end

end

class Project
  def activity;
  end
end
