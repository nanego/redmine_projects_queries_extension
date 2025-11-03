# frozen_string_literal: true

require 'spec_helper'
require 'queries_helper'

describe "Email columns rendering", type: :helper do
  fixtures :projects, :users, :roles, :members, :member_roles, :email_addresses

  before do
    User.current = nil
  end

  describe "role email columns display" do
    it "renders role_emails column for admin users" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      project = Project.first
      query = ProjectQuery.new
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.name).to eq("role_emails_#{role.id}".to_sym)
      expect(column.caption).to include("Role emails")
    end

    it "includes role name in the caption" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.caption).to include(role.name)
    end
  end

  describe "function email columns display" do
    before do
      skip "redmine_limited_visibility plugin not installed" unless Redmine::Plugin.installed?(:redmine_limited_visibility)
    end

    it "renders function_emails column for admin users" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      function = Function.first
      skip "No functions found" if function.nil?

      query = ProjectQuery.new
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryFunctionEmailColumn.new(function)

      expect(column.name).to eq("function_emails_#{function.id}".to_sym)
      expect(column.caption).to include("Function emails")
    end

    it "includes function name in the caption" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      function = Function.first
      skip "No functions found" if function.nil?

      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryFunctionEmailColumn.new(function)

      expect(column.caption).to include(function.name)
    end
  end

  describe "email columns configuration" do
    it "has sortable set to false" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      role = Role.find(1)
      role_email_column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(role_email_column.sortable?).to eq(false)
    end

    it "has groupable set to false" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      role = Role.find(1)
      role_email_column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(role_email_column.groupable?).to eq(false)
    end

    it "is an inline column" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      role = Role.find(1)
      role_email_column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(role_email_column.inline?).to eq(true)
    end
  end
end
