# frozen_string_literal: true

require 'spec_helper'
require 'queries_helper'

describe "Email columns rendering", type: :helper do
  fixtures :projects, :users, :roles, :members, :member_roles, :email_addresses

  describe "QueryRoleEmailColumn" do
    it "has correct name and caption" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.name).to eq("role_emails_#{role.id}".to_sym)
      expect(column.caption).to include("Role emails")
      expect(column.caption).to include(role.name)
    end

    it "has sortable set to false" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.sortable?).to eq(false)
    end

    it "has groupable set to false" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.groupable?).to eq(false)
    end

    it "is an inline column" do
      role = Role.find(1)
      column = RedmineProjectsQueriesExtension::ProjectQueryPatch::QueryRoleEmailColumn.new(role)

      expect(column.inline?).to eq(true)
    end
  end
end
