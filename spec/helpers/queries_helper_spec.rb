require 'spec_helper'
require 'queries_helper'
describe QueriesHelper, type: :helper do

  fixtures :projects, :trackers

  it "should group trackers columns" do
    options = filters_options_for_select(ProjectQuery.new)
    expect(options).to have_selector('optgroup[label=Date]',  count: 1)
    Tracker.all.each do |tracker|
      expect(options).to have_selector("optgroup > option[value=last_issue_date_#{tracker.id}]")
    end
  end

end
