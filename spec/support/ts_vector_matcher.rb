# frozen_string_literal: true

RSpec::Matchers.define :eq_ts_vector do |expected_vector|
  match do |actual_vector|
    actual = actual_vector.split(" ").sort
    expected = expected_vector.split(" ").sort

    (expected - actual == []) && (actual - expected == [])
  end
  failure_message do |actual_vector|
    actual = actual_vector.split(" ").sort
    expected = expected_vector.split(" ").sort

    message = +"ts_vector does not match!\n\n"
    message << "Additional elements:\n"
    message << (actual - expected).join("\n")
    message << "\nMissing elements:\n"
    message << (expected - actual).join("\n")
    message
  end
end
