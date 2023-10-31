module RedmineProjectsQueriesExtension

  class Hooks < Redmine::Hook::ViewListener
    def view_layouts_base_html_head(context)
      # stylesheet_link_tag("redmine_projects_queries_extension", :plugin => "redmine_projects_queries_extension") +
      #  javascript_include_tag("redmine_projects_queries_extension", :plugin => "redmine_projects_queries_extension")
    end
  end

  class ModelHook < Redmine::Hook::Listener
    def after_plugins_loaded(_context = {})
      require_relative 'application_controller_patch'
      require_relative 'projects_controller_patch'
      require_relative 'queries_helper_patch'
      require_relative 'project_query_patch'
    end
  end

end
