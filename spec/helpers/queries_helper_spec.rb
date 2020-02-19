require 'spec_helper'
require 'projects_queries_helper'
require 'redmine_projects_queries_extension/queries_helper_patch'

describe ProjectsQueriesHelper, type: :helper do

  fixtures :projects

  it "should display parent column as a link to a project" do
    query = ProjectQuery.new(:name => '_', :column_names => ["name", "parent_id"])
    content = column_value(QueryColumn.new(:parent_id), query.results_scope.select{|e| e.parent_id == 1}.first, Project.find(1))
    expect(content).to have_link("eCookbook")
  end

end
