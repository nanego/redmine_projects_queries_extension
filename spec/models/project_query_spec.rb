# frozen_string_literal: true

require 'spec_helper'
require File.dirname(__FILE__) + "/../support/projects_queries_extension_spec_helpers"

describe "ProjectQuery" do
  fixtures :projects, :users, :roles, :members, :member_roles, :issue_statuses,
           :trackers, :projects_trackers, :enumerations, :queries

  before do
    User.current = nil
  end

  it "should available filters should be ordered" do
    query = ProjectQuery.new
    expect(query.available_filters.keys.index('status')).to eq 0
    expect(query.available_filters.keys.index('id')).to eq 1
  end

  it "should project name filter in queries" do
    query = ProjectQuery.new(:name => '_')
    project_name_filter = query.available_filters["id"]
    refute_nil project_name_filter
    project_ids = project_name_filter[:values].map{|p| p[1]}
    assert project_ids.include?("1")  # public project
    assert !project_ids.include?("2") # private project user cannot see
  end

  def find_projects_with_query(query)
    Project.where(
      query.statement
    ).all
  end

  it "should query should allow id field for a project query" do
    project = Project.find(1)
    query = ProjectQuery.new(:name => '_')
    query.add_filter('id', '=', [project.id.to_s])
    assert query.statement.include?("#{Project.table_name}.id IN ('1')")
  end

  it "should operator none" do
    query = ProjectQuery.new(:name => '_')
    query.add_filter('id', '!*', [''])
    assert query.statement.include?("#{Project.table_name}.id IS NULL")
    find_projects_with_query(query)
  end

  it "should operator all" do
    query = ProjectQuery.new(:name => '_')
    query.add_filter('id', '*', [''])
    assert query.statement.include?("#{Project.table_name}.id IS NOT NULL")
    find_projects_with_query(query)
  end

  it "should operator is on integer custom field" do
    f = ProjectCustomField.create!(:name => 'filter', :field_format => 'int', :is_for_all => true, :is_filter => true)
    CustomValue.create!(:custom_field => f, :customized => Project.find(1), :value => '7')
    CustomValue.create!(:custom_field => f, :customized => Project.find(2), :value => '12')
    CustomValue.create!(:custom_field => f, :customized => Project.find(3), :value => '')

    query = ProjectQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '=', ['12'])
    projects = find_projects_with_query(query)
    expect(projects.size).to eq 1
    expect(projects.first.id).to eq 2
  end

  it "should operator is not on multi list custom field" do
    f = ProjectCustomField.create!(:name => 'filter', :field_format => 'list', :is_filter => true, :is_for_all => true,
                                 :possible_values => ['value1', 'value2', 'value3'], :multiple => true)
    CustomValue.create!(:custom_field => f, :customized => Project.find(1), :value => 'value1')
    CustomValue.create!(:custom_field => f, :customized => Project.find(1), :value => 'value2')
    CustomValue.create!(:custom_field => f, :customized => Project.find(3), :value => 'value1')

    query = ProjectQuery.new(:name => '_', :column_names => ["id", "name", "cf_#{f.id}"])
    query.add_filter("cf_#{f.id}", '!', ['value1'])
    projects = find_projects_with_query(query)
    assert !projects.map(&:id).include?(1)
    assert !projects.map(&:id).include?(3)

    query = ProjectQuery.new(:name => '_')
    query.add_filter("cf_#{f.id}", '!', ['value2'])
    projects = find_projects_with_query(query)
    assert !projects.map(&:id).include?(1)
    assert projects.map(&:id).include?(3)
  end

  it "should filter member" do
    User.current = User.find(3)
    query = ProjectQuery.new(:name => '_', :filters => { 'member_id' => {:operator => '=', :values => ['me']}})
    result = find_projects_with_query(query)
    refute_nil result
    assert !result.empty?
  end

  describe "Should filter last issue of tracker" do
    before do
      create_issues_for_test
    end

    it "operator >=" do
      future_date = Date.today.since(10.days).strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => '>=', :values => [future_date]}})
      projects = find_projects_with_query(query)

      expect(projects.size).to eq(0)

      twenty_days_ago_formatted = 20.days.ago.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => '>=', :values => [twenty_days_ago_formatted]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2) # project 1,4
      expect(projects.map(&:id)).to include(1, 4)
    end

    it "operator =" do
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => '=', :values => ["2012-06-16"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(Project.last.id)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => '=', :values => ["2012-06-16"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(0)
    end

    it "operator <=" do
      current_date_formatted = Date.today.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => '<=', :values => [current_date_formatted]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)

      seven_months_ago_formatted = 7.months.ago.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => '<=', :values => [seven_months_ago_formatted]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(2)
    end

    it "operator this week w" do
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => 'w', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => 'w', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => 'w', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator y this year" do
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => 'y', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, 4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => 'y', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => 'y', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator <t- more of " do
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => '<t-', :values => ["10"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, Project.last.id)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => '<t-', :values => ["10"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => '<t-', :values => ["10"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(2)
    end

    it "operator >t- less than " do
      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.first.id}" => {:operator => '>t-', :values => ["18"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, 4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => '>t-', :values => ["19"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                                :filters => { "last_issue_date_#{Tracker.third.id}" => {:operator => '>t-', :values => ["20"]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator lm last month" do
      query = ProjectQuery.new(:name => '_',
              :filters => { "last_issue_date_#{Tracker.second.id}" => {:operator => 'lm', :values => [""]}})
      projects = find_projects_with_query(query)
      expect(projects.size).to be >= 1
    end

    def create_issues_for_test
      date_test_this_week = random_date_this_week.to_s(:db)
      date_tomorrow_or_later = get_tomorrow_date_or_later.to_s(:db)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test1")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.fourth, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test2")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test3")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.fourth, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test4")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.last, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test5")
      update_last_issue_dates("2012-06-16 20:00:00")

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test6")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test7")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test8")
      update_last_issue_dates(13.months.ago.to_s(:db))

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test9")
      update_last_issue_dates(13.months.ago.to_s(:db))

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test10")
      update_last_issue_dates(2.weeks.ago.to_s(:db))

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test11")
      update_last_issue_dates(date_tomorrow_or_later)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test12")
      update_last_issue_dates(date_tomorrow_or_later)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test13")
      update_last_issue_dates(date_test_this_week)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test14")
      update_last_issue_dates(date_test_this_week)
    end
  end
end
