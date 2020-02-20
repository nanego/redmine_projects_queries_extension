RedmineApp::Application.routes.draw do
  post "plugin_projects_queries_extension_get_mail_addresses", :to => "projects#get_mail_addresses"
end
