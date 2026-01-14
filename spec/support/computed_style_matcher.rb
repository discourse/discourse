# frozen_string_literal: true

RSpec::Matchers.define :have_computed_style do |expected|
  match do |element|
    actual = normalize(computed_style(element, expected.keys.first))
    actual == normalize(expected.values.first)
  end

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

  def normalize(value)
    match =
      /
      \A(?<prefix>(?:ok)?lch)
      \(
        (?<l>.+)(?<symbol>%?)\s
        (?<c>.+)\s
        (?<h>.+)
      \)\Z
    /x.match(
        value,
      )

    return value if !match

    l = format("%.2f", BigDecimal(match[:l]).truncate(2))
    c = format("%.2f", BigDecimal(match[:c]).truncate(2))
    h = format("%.2f", BigDecimal(match[:h]).truncate(2))

    "#{match[:prefix]}(#{l}#{match[:symbol]} #{c} #{h})"
  end
end
