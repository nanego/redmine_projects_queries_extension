require 'spec_helper'

describe ProjectsController, type: :controller do
  render_views

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

end
