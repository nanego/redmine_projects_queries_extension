require 'spec_helper'
require 'queries_helper'
describe QueriesHelper, type: :helper do

  fixtures :projects, :trackers

  it "should group trackers columns" do
    options = filters_options_for_select(ProjectQuery.new)
    expect(options).to have_selector('optgroup[label=Date]', count: 1)
    Tracker.pluck(:id).each do |tracker_id|
      expect(options).to have_selector("optgroup > option[value=last_issue_date_for_tracker_#{tracker_id}]")
    end
  end

end
