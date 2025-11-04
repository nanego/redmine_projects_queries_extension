# frozen_string_literal: true

require 'spec_helper'

describe "ProjectQuery email columns" do
  fixtures :projects, :users, :roles, :members, :member_roles, :issue_statuses,
           :trackers, :projects_trackers, :enumerations, :queries, :email_addresses

  describe "QueryRoleEmailColumn" do
    it "is defined as a QueryColumn subclass" do
      role = Role.first
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column).to be_a(QueryColumn)
    end

    it "has correct name format" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.name).to eq("role_emails_#{role.id}".to_sym)
    end

    it "has caption including role name" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.caption).to include("Role emails")
      expect(column.caption).to include(role.name)
    end

    it "has sortable set to false" do
      role = Role.first
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.sortable?).to eq(false)
    end

    it "has groupable set to false" do
      role = Role.first
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.groupable?).to eq(false)
    end

    it "is an inline column" do
      role = Role.first
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.inline?).to eq(true)
    end
  end

  describe "QueryFunctionEmailColumn" do
    it "is defined as a QueryColumn subclass" do
      role = Role.first
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryFunctionEmailColumn.new(role)

      expect(column).to be_a(QueryColumn)
    end
  end
end
