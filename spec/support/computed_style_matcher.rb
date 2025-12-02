# frozen_string_literal: true

RSpec::Matchers.define :have_computed_style do |expected|
  match { |element| computed_style(element, expected.keys.first) == expected.values.first }

  failure_message do |element|
    actual = computed_style(element, expected.keys.first)
    "expected the element to have #{expected.keys.first} with the value '#{expected.values.first}', but the value is '#{actual}'"
  end

  failure_message_when_negated do |element|
    "expected the element not to have #{expected.keys.first} with the value #{expected.values.first}, but it does"
  end

  def computed_style(element, property)
    element.evaluate_script("getComputedStyle(this)['#{property}']")
  end
end
