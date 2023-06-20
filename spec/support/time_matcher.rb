# frozen_string_literal: true

RSpec::Matchers.define :be_within_one_second_of do |expected_time|
  match { |actual_time| (actual_time - expected_time).abs < 1 }
  failure_message { |actual_time| "#{actual_time} is not within 1 second of #{expected_time}" }
end

RSpec::Matchers.define :be_within_one_minute_of do |expected_time|
  match { |actual_time| (actual_time - expected_time).abs < 60 }
  failure_message { |actual_time| "#{actual_time} is not within 1 minute of #{expected_time}" }
end

RSpec::Matchers.define :eq_time do |expected_time|
  match do |actual_time|
    return true if expected_time.nil? && actual_time.nil?
    return false if expected_time.nil? || actual_time.nil?
    (actual_time - expected_time).abs < 0.001
  end
  failure_message { |actual_time| "#{actual_time} is not within 1 millisecond of #{expected_time}" }
  failure_message_when_negated do |actual_time|
    "#{actual_time} is within 1 millisecond of #{expected_time}"
  end
end
