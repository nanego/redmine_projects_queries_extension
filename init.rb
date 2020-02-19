require 'redmine'

ActiveSupport::Reloader.to_prepare do
  require_dependency 'redmine_projects_queries_extension/application_controller_patch'
  require_dependency 'redmine_projects_queries_extension/projects_controller_patch'
  require_dependency 'redmine_projects_queries_extension/queries_helper_patch'
  require_dependency 'redmine_projects_queries_extension/project_query_patch'
end

Redmine::Plugin.register :redmine_projects_queries_extension do
  name 'Redmine Projects Queries Extension plugin'
  description 'This plugin provides additional filters and columns to projects queries'
  url 'https://github.com/nanego/redmine_projects_queries_extension'
  author 'Vincent ROBERT'
  author_url 'https://github.com/nanego'
  requires_redmine :version_or_higher => '4.1.0'
  requires_redmine_plugin :redmine_base_deface, :version_or_higher => '0.0.1'
  requires_redmine_plugin :redmine_base_rspec, :version_or_higher => '0.0.4' if Rails.env.test?
  version '4.1.0'
end
