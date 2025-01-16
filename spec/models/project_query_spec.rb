# frozen_string_literal: true

require 'spec_helper'
require_relative "../support/projects_queries_extension_spec_helpers"

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
    project_ids = project_name_filter[:values].map { |p| p[1] }
    assert project_ids.include?("1") # public project
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
    query = ProjectQuery.new(:name => '_', :filters => { 'member_id' => { :operator => '=', :values => ['me'] } })
    result = find_projects_with_query(query)
    refute_nil result
    assert !result.empty?
  end

  describe "Should filter last issue of tracker" do
    before do
      create_issues_for_test
    end

    let(:last_project) { Project.last }

    it "operator >=" do
      future_date = Date.today.since(10.days).strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '>=', :values => [future_date] } })
      projects = find_projects_with_query(query)

      expect(projects.size).to eq(0)

      twenty_days_ago_formatted = 20.days.ago.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '>=', :values => [twenty_days_ago_formatted] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2) # project 1,4
      expect(projects.map(&:id)).to include(1, 4)
    end

    it "operator =" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '=', :values => ["2012-06-16"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(last_project.id)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => '=', :values => ["2012-06-16"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(0)
    end

    it "operator <=" do
      current_date_formatted = Date.today.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '<=', :values => [current_date_formatted] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)

      seven_months_ago_formatted = 7.months.ago.strftime("%Y-%m-%d")
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '<=', :values => [seven_months_ago_formatted] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(2)
    end

    it "operator this week w" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => 'w', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => 'w', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => 'w', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator y this year" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => 'y', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, 4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => 'y', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => 'y', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator <t- more of " do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '<t-', :values => ["10"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, last_project.id)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => '<t-', :values => ["10"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '<t-', :values => ["10"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(2)
    end

    it "operator >t- less than " do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '>t-', :values => ["18"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(1, 4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => '>t-', :values => ["19"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '>t-', :values => ["20"] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator !* None" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '!*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(3)

      expect(projects.map(&:id)).to include(2, 3, 5)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => '!*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(5)
      expect(projects.map(&:id)).to_not include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '!*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(4)
      expect(projects.map(&:id)).to_not include(2, 4)
    end

    it "operator * All" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_1" => { :operator => '*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(3)
      expect(projects.map(&:id)).to include(1, 4, last_project.id)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => '*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(1)
      expect(projects.map(&:id)).to include(4)

      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_3" => { :operator => '*', :values => [""] } })
      projects = find_projects_with_query(query)
      expect(projects.size).to eq(2)
      expect(projects.map(&:id)).to include(2, 4)
    end

    it "operator lm last month" do
      query = ProjectQuery.new(:name => '_',
                               :filters => { "last_issue_date_for_tracker_2" => { :operator => 'lm', :values => [""] } })
      projects = find_projects_with_query(query)

      expect(projects.size).to be >= 1
      expect(projects.map(&:id)).to include(4) # project 4 has an issue created last month
    end

    def db_formatted_date(date)
      if date.respond_to?(:to_fs)
        date.to_fs(:db) # Redmine 6 and later
      else
        date.to_s(:db) # Redmine 5
      end
    end

    def create_issues_for_test

      past_date_this_week = db_formatted_date(random_date_this_week)
      future_date_tomorrow_or_later = db_formatted_date(get_tomorrow_date_or_later)

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 1,
                                  tracker_id: 1,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test1" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 4, tracker_id: 1,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test2" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 4, tracker_id: 2,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test3" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 4, tracker_id: 3,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test4" })

      create_issue_with(creation_date: "2012-06-16 20:00:00",
                        params: { :project => last_project, tracker_id: 1,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test5" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 2, tracker_id: 3,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test6" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 1, tracker_id: 1,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test7" })

      create_issue_with(creation_date: db_formatted_date(13.months.ago),
                        params: { project_id: 1, tracker_id: 1,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test8" })

      create_issue_with(creation_date: db_formatted_date(13.months.ago),
                        params: { project_id: 2, tracker_id: 3,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test9" })

      create_issue_with(creation_date: db_formatted_date(2.weeks.ago),
                        params: { project_id: 4, tracker_id: 2,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test10" })

      create_issue_with(creation_date: future_date_tomorrow_or_later,
                        params: { project_id: 2, tracker_id: 3,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test11" })

      create_issue_with(creation_date: future_date_tomorrow_or_later,
                        params: { project_id: 4, tracker_id: 2,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test12" })

      create_issue_with(creation_date: past_date_this_week,
                        params: { project_id: 4, tracker_id: 2,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test13" })

      create_issue_with(creation_date: db_formatted_date(Date.today.prev_month),
                        params: { project_id: 4, tracker_id: 2,
                                  author_id: 1, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test14" })

    end
  end
end
