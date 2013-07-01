RSpec::Matchers.define :be_within_one_second_of do |expected_time|
  match do |actual_time|
    (actual_time - expected_time).abs < 1
  end
  failure_message_for_should do |actual_time|
    "#{actual_time.to_s} is not within 1 second of #{expected_time}"
  end
end