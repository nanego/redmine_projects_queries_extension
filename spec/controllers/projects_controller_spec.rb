# frozen_string_literal: true

require 'spec_helper'
require "active_support/testing/assertions"
require File.dirname(__FILE__) + "/../support/projects_queries_extension_spec_helpers"

describe ProjectsController, type: :controller do
  fixtures :projects, :users, :roles, :members, :member_roles, :issue_statuses,
           :trackers, :projects_trackers, :enumerations, :queries

  include ActiveSupport::Testing::Assertions
  render_views
  include Redmine::I18n

  before do
    # reset current user
    User.current = nil
  end

  def teardown
    # delete project queries so they don't interfer with other tests
    ProjectQuery.destroy_all
  end

  it "should index with default filter" do
    get :index, params: {:set_filter => 1}
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    # default filter
    assert_equal({'status' => {:operator => '=', :values => ['1']}}, query.filters)
  end

  it "should index with filter" do
    get :index, params: {:set_filter => 1,
                         :f => ['is_public'],
                         :op => {'is_public' => '='},
                         :v => {'is_public' => ['0']}}
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    assert_equal({'is_public' => {:operator => '=', :values => ['0']}}, query.filters)
  end

  it "should index with empty filters" do
    get :index, params: {:set_filter => 1, :fields => ['']}
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    # no filter
    assert_equal({}, query.filters)
  end

  it "should index csv with all columns" do
    get :index, params: {:format => 'csv', :c => ['all_inline']}
    expect(response).to be_successful
    refute_nil assigns(:entries)
    expect(response.content_type).to eq 'text/csv; header=present'
    lines = response.body.chomp.split("\n")
    expect(lines[0].split(',').size).to eq assigns(:query).available_inline_columns.size
  end

  it "should index with columns" do
    columns = ['name', 'status', 'created_on']
    get :index, params: {:set_filter => 1, :c => columns}
    expect(response).to be_successful

    # query should use specified columns
    query = assigns(:query)
    assert_kind_of ProjectQuery, query
    expect(query.column_names.map(&:to_s)).to eq columns
  end

  describe "content columns in csv" do
    before do
      create_issues_for_test
    end

    let(:tracker_1) { Tracker.find(1) }
    let(:tracker_2) { Tracker.find(2) }
    let(:tracker_3) { Tracker.find(3) }

    let(:tomorrow_date_formatted) { Date.tomorrow.to_s(:db) }
    let(:two_days_ago_formatted) { 2.days.ago.to_s(:db) }
    let(:twelve_years_ago_formatted) { 12.years.ago.to_s(:db) }

    it "public projects" do
      columns = ["name", "last_issue_date_#{tracker_1.id}",
                 "last_issue_date_#{tracker_2.id}",
                 "last_issue_date_#{tracker_3.id}"]
      get :index, params: { :set_filter => 1,
                            :c => columns,
                            :format => 'csv' }

      expect(response).to be_successful
      expect(response.content_type).to eq 'text/csv; header=present'

      lines = response.body.chomp.split("\n")

      expect(lines[0].split(',')[0]).to eq "Name"
      expect(lines[0].split(',')[1]).to eq "Last issue #{tracker_1.name}"
      expect(lines[0].split(',')[2]).to eq "Last issue #{tracker_2.name}"
      expect(lines[0].split(',')[3]).to eq "Last issue #{tracker_3.name}"

      expect(lines[1].split(',')[0]).to eq Project.first.name
      expect(lines[1].split(',')[1].split[0]).to eq format_date(two_days_ago_formatted)
      expect(lines[1].split(',')[2]).to eq "\"\""
      expect(lines[1].split(',')[3]).to eq "\"\""

      expect(lines[2].split(',')[0]).to eq Project.last.name # first public child of first project
      expect(lines[2].split(',')[1].split[0]).to eq format_date(twelve_years_ago_formatted)
      expect(lines[2].split(',')[2]).to eq "\"\""
      expect(lines[2].split(',')[3]).to eq "\"\""

      expect(lines[3].split(',')[0]).to eq Project.third.name # second public child of first project
      expect(lines[3].split(',')[1]).to eq "\"\""
      expect(lines[3].split(',')[2]).to eq "\"\""
      expect(lines[3].split(',')[3]).to eq "\"\""

      expect(lines[4].split(',')[0]).to eq Project.fourth.name # third public child of first project
      expect(lines[4].split(',')[1].split[0]).to eq format_date(two_days_ago_formatted)
      expect(lines[4].split(',')[2].split[0]).to eq format_date(tomorrow_date_formatted)
      expect(lines[4].split(',')[3].split[0]).to eq format_date(two_days_ago_formatted)
    end

    it "private projects" do
      @request.session[:user_id] = 1 # permissions admin
      columns = ["name", "last_issue_date_#{tracker_1.id}",
                 "last_issue_date_#{tracker_2.id}",
                 "last_issue_date_#{tracker_3.id}"]
      get :index, params: { :set_filter => 1,
                            :f => ["is_public", ""],
                            :v => { "is_public" => ["1"] },
                            :op => { "is_public" => "!" },
                            :c => columns,
                            :format => 'csv' }

      expect(response).to be_successful
      expect(response.content_type).to eq 'text/csv; header=present'

      lines = response.body.chomp.split("\n")

      expect(lines[0].split(',')[0]).to eq "Name"
      expect(lines[0].split(',')[1]).to eq "Last issue #{tracker_1.name}"
      expect(lines[0].split(',')[2]).to eq "Last issue #{tracker_2.name}"
      expect(lines[0].split(',')[3]).to eq "Last issue #{tracker_3.name}"

      expect(lines[1].split(',')[0]).to eq Project.find(5).name # child of first project
      expect(lines[1].split(',')[1]).to eq "\"\""
      expect(lines[1].split(',')[2]).to eq "\"\""
      expect(lines[1].split(',')[3]).to eq "\"\""

      expect(lines[2].split(',')[0]).to eq Project.second.name
      expect(lines[2].split(',')[1]).to eq "\"\""
      expect(lines[2].split(',')[2]).to eq "\"\""
      expect(lines[2].split(',')[3].split[0]).to eq format_date(tomorrow_date_formatted)
    end

    def create_issues_for_test
      thirteen_months_ago_formatted = 13.months.ago.to_s(:db)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue project_first tracker_first 1")
      update_last_issue_dates(two_days_ago_formatted)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue project_first tracker_first 2")
      update_last_issue_dates(3.days.ago.to_s(:db))

      Issue.create(:project => Project.fourth, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test2")
      update_last_issue_dates(two_days_ago_formatted)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test3")
      update_last_issue_dates(two_days_ago_formatted)

      Issue.create(:project => Project.fourth, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test4")
      update_last_issue_dates(two_days_ago_formatted)

      Issue.create(:project => Project.last, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test5")
      update_last_issue_dates(twelve_years_ago_formatted)

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test6")
      update_last_issue_dates(two_days_ago_formatted)

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test7")
      update_last_issue_dates(7.days.ago.to_s(:db))

      Issue.create(:project => Project.first, :tracker => Tracker.first,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test8")
      update_last_issue_dates(thirteen_months_ago_formatted)

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test9")
      update_last_issue_dates(thirteen_months_ago_formatted)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test10")
      update_last_issue_dates(2.weeks.ago.to_s(:db))

      Issue.create(:project => Project.second, :tracker => Tracker.third,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test11")
      update_last_issue_dates(tomorrow_date_formatted)

      Issue.create(:project => Project.fourth, :tracker => Tracker.second,
        :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
        :subject => "Issue test12")
      update_last_issue_dates(tomorrow_date_formatted)
    end
  end
end
