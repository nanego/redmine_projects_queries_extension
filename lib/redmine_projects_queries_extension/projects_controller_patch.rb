require_dependency 'projects_controller'
require_dependency 'project'

module RedmineProjectsQueriesExtension
  module ProjectsControllerPatch

    def preload_memberships
      #pre-load current user's memberships
      @memberships = User.current.memberships.inject({}) do |memo, membership|
        memo[membership.project_id] = membership.roles
        memo
      end
    end

    def members_cache_key
      @members_cache_key ||= Member.maximum("created_on").to_i
    end

    def organizations_cache_key
      @organizations_cache_key ||= Organization.maximum("updated_at").to_i
    end

    def email_addresses_cache_key
      @email_addresses_cache_key ||= EmailAddress.maximum("updated_on").to_i
    end

    def trackers_issues_cache_key
      @trackers_issues_cache_key ||= [Project.maximum("created_on").to_i, Tracker.maximum("id").to_i, Issue.maximum("updated_on").to_i].join('/')
    end

    def members_map
      @members_map ||= Rails.cache.fetch("projects-members-#{members_cache_key}") do
        user_names_map = @query.all_users.each_with_object({}) { |u, h| h[u.id] = u.name }

        map = Hash.new { |h, k| h[k] = [] }
        Member.joins(:user)
              .where(users: { status: Principal::STATUS_ACTIVE })
              .pluck("#{Member.table_name}.project_id", "#{Member.table_name}.user_id")
              .each do |project_id, user_id|
          name = user_names_map[user_id]
          map[project_id] << name if name.present?
        end

        map.transform_values { |names| names.join(', ').html_safe }
      end
    end

    def organizations_map
      cache_strategy = ['all-organizations', members_cache_key, organizations_cache_key, 2].join('/')
      @organizations_map ||= Rails.cache.fetch cache_strategy do
        orgas_fullnames = {}
        Organization.find_each do |o|
          orgas_fullnames[o.id] = o.fullname
        end

        sql = Organization.select("organizations.id, project_id, role_id").
          joins(:users => {:members => :member_roles}).
          where("users.status = ?", Principal::STATUS_ACTIVE).
          order("project_id, role_id, organizations.id").
          group("project_id, role_id, organizations.id").to_sql
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
          sql = Organization.select("organizations.id, project_id, function_id").
            joins(:users => {:members => :member_functions}).
            where("users.status = ?", Principal::STATUS_ACTIVE).
            order("project_id, function_id, organizations.id").
            group("project_id, function_id, organizations.id").to_sql
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

    def trackers_issues_map
      @trackers_issues_map ||= Rails.cache.fetch("all-projects-#{trackers_issues_cache_key}") do
        sql = Issue.select("project_id, tracker_id, Max(created_on)").
          group("project_id, tracker_id").to_sql
        array = ActiveRecord::Base.connection.execute(sql)
        map = {}
        array.each do |record|
          unless map[record["project_id"]]
            map[record["project_id"]] = {}
          end
          unless map[record["project_id"]]["last_issue_date_for_tracker_#{record["tracker_id"]}"]
            map[record["project_id"]]["last_issue_date_for_tracker_#{record["tracker_id"]}"] = []
          end
          parsed_date = Time.parse(record["max"].to_s)
          formatted_date = format_object(parsed_date)
          map[record["project_id"]]["last_issue_date_for_tracker_#{record["tracker_id"]}"] = formatted_date
        end
        map
      end
    end

    def directions_map
      @directions_map ||= Rails.cache.fetch(['all-directions', members_cache_key, organizations_cache_key].join('/')) do
        # Load all organizations once and index by id
        all_orgs = Organization.all.index_by(&:id)

        # Compute direction_organization in memory to avoid N+1 parent traversal
        direction_cache = {}
        find_direction = lambda do |org|
          direction_cache[org.id] ||= if org.direction? || org.parent_id.nil?
            org
          else
            find_direction.call(all_orgs[org.parent_id])
          end
        end

        # Load all project-organization links in one query instead of one per project
        raw_map = Hash.new { |h, k| h[k] = [] }
        Organization.joins(:users => :members)
                    .where("users.status = ?", Principal::STATUS_ACTIVE)
                    .pluck("members.project_id", "organizations.id")
                    .each do |project_id, org_id|
          org = all_orgs[org_id]
          next unless org
          raw_map[project_id] << find_direction.call(org).name
        end

        raw_map.each_with_object({}) do |(project_id, directions), map|
          map[project_id] = directions.uniq.join(', ').html_safe
        end
      end
    end

    def role_emails_map
      @role_emails_map ||= Rails.cache.fetch(['all-role-emails', members_cache_key, email_addresses_cache_key].join('/')) do
        map = {}
        sql = Member.select("project_id, role_id, email_addresses.address").
          joins(:user).
          joins("LEFT JOIN email_addresses ON users.id = email_addresses.user_id AND email_addresses.is_default = true").
          joins(:member_roles).
          where("users.status = ?", Principal::STATUS_ACTIVE).
          order("project_id, role_id, email_addresses.address").
          group("project_id, role_id, email_addresses.address").to_sql
        array = ActiveRecord::Base.connection.execute(sql)
        array.each do |record|
          unless map[record["project_id"]]
            map[record["project_id"]] = {}
          end
          unless map[record["project_id"]][record["role_id"]]
            map[record["project_id"]][record["role_id"]] = []
          end
          map[record["project_id"]][record["role_id"]] << record["address"] if record["address"].present?
        end
        map
      end
    end

    def function_emails_map
      @function_emails_map ||= Rails.cache.fetch(['all-function-emails', members_cache_key, email_addresses_cache_key].join('/')) do
        map = {}
        sql = Member.select("project_id, function_id, email_addresses.address").
          joins(:user).
          joins("LEFT JOIN email_addresses ON users.id = email_addresses.user_id AND email_addresses.is_default = true").
          joins(:member_functions).
          where("users.status = ?", Principal::STATUS_ACTIVE).
          order("project_id, function_id, email_addresses.address").
          group("project_id, function_id, email_addresses.address").to_sql
        array = ActiveRecord::Base.connection.execute(sql)
        array.each do |record|
          unless map[record["project_id"]]
            map[record["project_id"]] = {}
          end
          unless map[record["project_id"]][record["function_id"]]
            map[record["project_id"]][record["function_id"]] = []
          end
          map[record["project_id"]][record["function_id"]] << record["address"] if record["address"].present?
        end
        map
      end
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
            all_users = all_users | project.principals_by_role[role] if project.principals_by_role[role]
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

  end
end

class ProjectsController

  prepend RedmineProjectsQueriesExtension::ProjectsControllerPatch

  before_action :preload_memberships, only: [:index]

  skip_before_action :find_project, :only => [:get_mail_addresses]
  skip_before_action :authorize, :only => [:get_mail_addresses]

  helper_method :members_map
  helper_method :organizations_map
  helper_method :directions_map
  helper_method :trackers_issues_map
  helper_method :role_emails_map
  helper_method :function_emails_map
end

class Project
  def activity;
  end
end
