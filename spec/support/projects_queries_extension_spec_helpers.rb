# frozen_string_literal: true

require "spec_helper"

def get_tomorrow_date_or_later
  todaye = DateTime.now
  tomorrow = todaye + 1
  if tomorrow.cweek == todaye.cweek
    return tomorrow
  else
    return todaye + Rational(3, 24)
  end
end

def random_date_this_week
  today = Date.today
  days_passed = rand(0..today.wday) # Select a random number of days passed this week
  return today - days_passed
end

def random_date_last_month
  today = Date.today
  days_in_last_month = (today - 1.month).end_of_month.day
  days_passed = rand(0..days_in_last_month - 1) # Select a random number of days passed last month
  return (today - 1.month).at_end_of_month - days_passed
end

def update_last_issue_dates(new_date)
  issue = Issue.last
  issue.update(:created_on => new_date, :updated_on => new_date)
  issue.save
end
