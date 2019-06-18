# frozen_string_literal: true

RSpec::Matchers.define :be_within_one_second_of do |expected_time|
  match do |actual_time|
    (actual_time - expected_time).abs < 1
  end
  failure_message do |actual_time|
    "#{actual_time} is not within 1 second of #{expected_time}"
  end
end

RSpec::Matchers.define :eq_time do |expected_time|
  match do |actual_time|
    (actual_time - expected_time).abs < 0.001
  end
  failure_message do |actual_time|
    "#{actual_time} is not within 1 millisecond of #{expected_time}"
  end
end
