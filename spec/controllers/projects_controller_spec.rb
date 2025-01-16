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
    get :index, params: { :set_filter => 1 }
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    # default filter
    assert_equal({ 'status' => { :operator => '=', :values => ['1'] } }, query.filters)
  end

  it "should index with filter" do
    get :index, params: { :set_filter => 1,
                          :f => ['is_public'],
                          :op => { 'is_public' => '=' },
                          :v => { 'is_public' => ['0'] } }
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    assert_equal({ 'is_public' => { :operator => '=', :values => ['0'] } }, query.filters)
  end

  it "should index with empty filters" do
    get :index, params: { :set_filter => 1, :fields => [''] }
    expect(response).to be_successful
    assert_template 'index'
    refute_nil assigns(:entries)

    query = assigns(:query)
    refute_nil query
    # no filter
    assert_equal({}, query.filters)
  end

  it "should index csv with all columns" do
    get :index, params: { :format => 'csv', :c => ['all_inline'] }
    expect(response).to be_successful
    refute_nil assigns(:query)
    expect(response.content_type).to eq 'text/csv; header=present'
    lines = response.body.chomp.split("\n")
    expect(lines[0].split(',').size).to eq assigns(:query).available_inline_columns.size
  end

  it "should index with columns" do
    columns = ['name', 'status', 'created_on']
    get :index, params: { :set_filter => 1, :c => columns }
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

    let(:tomorrow_date_formatted) { db_formatted_date(Date.tomorrow) }
    let(:two_days_ago_formatted) { db_formatted_date(2.days.ago) }
    let(:twelve_years_ago_formatted) { db_formatted_date(12.years.ago) }

    it "displays only public projects for anonymous users " do
      columns = ["name", "last_issue_date_for_tracker_#{tracker_1.id}",
                 "last_issue_date_for_tracker_#{tracker_2.id}",
                 "last_issue_date_for_tracker_#{tracker_3.id}"]
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

    it "displays only private projects when user has permission and is_public is false" do
      @request.session[:user_id] = 1 # permissions admin
      columns = ["name", "last_issue_date_for_tracker_#{tracker_1.id}",
                 "last_issue_date_for_tracker_#{tracker_2.id}",
                 "last_issue_date_for_tracker_#{tracker_3.id}"]
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

    def db_formatted_date(date)
      if date.respond_to?(:to_fs)
        date.to_fs(:db) # Redmine 6 and later
      else
        date.to_s(:db) # Redmine 5
      end
    end

    def create_issues_for_test
      thirteen_months_ago_formatted = db_formatted_date(13.months.ago)

      create_issue_with(creation_date: two_days_ago_formatted,
                        params: { project_id: 1, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue project_first tracker_first 1" })

      create_issue_with(creation_date: db_formatted_date(3.days.ago),
                        params: { project_id: 1, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue project_first tracker_first 2" })

      create_issue_with(creation_date: two_days_ago_formatted,
                        params: { :project => Project.fourth, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test2" })

      create_issue_with(creation_date: two_days_ago_formatted,
                        params: { :project => Project.fourth, :tracker => Tracker.second,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test3" })

      create_issue_with(creation_date: two_days_ago_formatted,
                        params: { :project => Project.fourth, :tracker => Tracker.third,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test4" })

      create_issue_with(creation_date: twelve_years_ago_formatted,
                        params: { :project => Project.last, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test5" })

      create_issue_with(creation_date: two_days_ago_formatted,
                        params: { :project => Project.second, :tracker => Tracker.third,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test6" })

      create_issue_with(creation_date: db_formatted_date(7.days.ago),
                        params: { project_id: 1, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test7" })

      create_issue_with(creation_date: thirteen_months_ago_formatted,
                        params: { project_id: 1, :tracker => Tracker.first,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test8" })

      create_issue_with(creation_date: thirteen_months_ago_formatted,
                        params: { :project => Project.second, :tracker => Tracker.third,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test9" })

      create_issue_with(creation_date: db_formatted_date(2.weeks.ago),
                        params: { :project => Project.fourth, :tracker => Tracker.second,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test10" })

      create_issue_with(creation_date: tomorrow_date_formatted,
                        params: { :project => Project.second, :tracker => Tracker.third,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test11" })

      create_issue_with(creation_date: tomorrow_date_formatted,
                        params: { :project => Project.fourth, :tracker => Tracker.second,
                                  :author => User.first, :status_id => IssueStatus.first, :priority => IssuePriority.first,
                                  :subject => "Issue test12" })

    end
  end
end
