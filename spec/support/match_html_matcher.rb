# frozen_string_literal: true

RSpec::Matchers.define :match_html do |expected|
  match { |actual| make_canonical_html(expected).eql? make_canonical_html(actual) }

  failure_message do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n to match:\n#{expected}"
  end

  failure_message_when_negated do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n not to match:\n#{expected}"
  end

  def make_canonical_html(html)
    doc = Nokogiri.HTML5(html)

    doc.traverse do |node|
      node.content = node.content.gsub(/\s+/, " ").strip if node.node_name&.downcase == "text"
    end

    doc.to_html
  end
end
