# frozen_string_literal: true

require 'spec_helper'

describe "ProjectQuery email columns" do
  fixtures :projects, :users, :roles, :members, :member_roles, :issue_statuses,
           :trackers, :projects_trackers, :enumerations, :queries

  before do
    User.current = nil
  end

  describe "QueryRoleEmailColumn" do
    it "creates a column for each non-builtin role" do
      query = ProjectQuery.new
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      role_email_columns = query.available_columns.select { |c| c.name.to_s.start_with?('role_emails_') }
      non_builtin_roles = Role.where("builtin = 0").order("position asc")

      expect(role_email_columns.size).to eq(non_builtin_roles.size)
    end

    it "is not available for non-admin users" do
      query = ProjectQuery.new
      non_admin_user = User.find(2)
      User.current = non_admin_user

      role_email_columns = query.available_columns.select { |c| c.name.to_s.start_with?('role_emails_') }

      expect(role_email_columns.size).to eq(0)
    end

    it "has correct caption format" do
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      query = ProjectQuery.new
      role = Role.find(1)
      role_email_column = query.available_columns.find { |c| c.name == "role_emails_#{role.id}".to_sym }

      expect(role_email_column).not_to be_nil
      expect(role_email_column.caption).to include("Role emails")
      expect(role_email_column.caption).to include(role.name)
    end
  end

  describe "QueryFunctionEmailColumn" do
    before do
      skip "redmine_limited_visibility plugin not installed" unless Redmine::Plugin.installed?(:redmine_limited_visibility)
    end

    it "creates a column for each function if plugin is installed" do
      query = ProjectQuery.new
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      function_email_columns = query.available_columns.select { |c| c.name.to_s.start_with?('function_emails_') }

      if Redmine::Plugin.installed?(:redmine_limited_visibility)
        functions = Function.order("position asc")
        expect(function_email_columns.size).to eq(functions.size)
      end
    end

    it "is not available if limited_visibility plugin is not installed" do
      skip "Test only applies when plugin is not installed" if Redmine::Plugin.installed?(:redmine_limited_visibility)

      query = ProjectQuery.new
      admin_user = User.find_by(admin: true)
      User.current = admin_user

      function_email_columns = query.available_columns.select { |c| c.name.to_s.start_with?('function_emails_') }
      expect(function_email_columns.size).to eq(0)
    end

    it "is not available for non-admin users" do
      skip "redmine_limited_visibility plugin not installed" unless Redmine::Plugin.installed?(:redmine_limited_visibility)

      query = ProjectQuery.new
      non_admin_user = User.find(2)
      User.current = non_admin_user

      function_email_columns = query.available_columns.select { |c| c.name.to_s.start_with?('function_emails_') }
      expect(function_email_columns.size).to eq(0)
    end

    it "has correct caption format" do
      skip "redmine_limited_visibility plugin not installed" unless Redmine::Plugin.installed?(:redmine_limited_visibility)

      admin_user = User.find_by(admin: true)
      User.current = admin_user

      query = ProjectQuery.new
      function = Function.first
      skip "No functions found" if function.nil?

      function_email_column = query.available_columns.find { |c| c.name == "function_emails_#{function.id}".to_sym }

      expect(function_email_column).not_to be_nil
      expect(function_email_column.caption).to include("Function emails")
      expect(function_email_column.caption).to include(function.name)
    end
  end
end
