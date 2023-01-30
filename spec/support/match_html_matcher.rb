# frozen_string_literal: true

require "nokogiri/xml/parse_options"
RSpec::Matchers.define :match_html do |expected|
  match { |actual| make_canonical_html(expected).eql? make_canonical_html(actual) }

  failure_message do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n to match:\n#{expected}"
  end

  failure_message_when_negated do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n not to match:\n#{expected}"
  end

  def make_canonical_html(html)
    doc =
      Nokogiri.HTML5(html) do |config|
        config[:options] = Nokogiri::XML::ParseOptions::NOBLANKS |
          Nokogiri::XML::ParseOptions::COMPACT
      end

    doc.traverse do |node|
      node.content = node.content.gsub(/\s+/, " ").strip if node.node_name&.downcase == "text"
    end

    doc.to_html
  end
end
