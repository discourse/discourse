# frozen_string_literal: true
include Rails::Dom::Testing::Assertions::DomAssertions

RSpec::Matchers.define :be_same_dom do |expected|
  match do |actual|
    begin
      assert_dom_equal(expected, actual)
    rescue MiniTest::Assertion
      false
    end
  end

  failure_message { |actual| "Expected DOM:\n#{expected}\nto be the same as:\n#{actual}" }
end
