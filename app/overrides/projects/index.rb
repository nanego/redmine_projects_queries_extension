Deface::Override.new :virtual_path  => 'projects/index',
                     :original      => '0b749d9eec363aebe78c455314e5d87f02ab72a2',
                     :name          => 'add-resources-to-projects-index-page',
                     :insert_before => ".contextual",
                     :text          => <<SCRIPT

<% content_for :header_tags do %>
  <%= javascript_include_tag 'jquery.peity.min.js', :plugin => 'redmine_projects_queries_extension' %>
  <%= javascript_include_tag 'projects_queries_extension', :plugin => 'redmine_projects_queries_extension' %>
  <%= stylesheet_link_tag 'projects_queries_extension', :plugin => 'redmine_projects_queries_extension' %>
<% end %>

SCRIPT

Deface::Override.new :virtual_path  => 'projects/index',
                     :original      => 'd3fb826a2bd63adc1df8f1fd9d6bd3706a548bab',
                     :name          => 'add-email-export-link-on-the-projects-page',
                     :insert_before => 'erb[silent]:contains("html_title(l(:label_project_plural))")',
                     :partial       => 'projects/link_to_export'
