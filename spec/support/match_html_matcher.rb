require 'nokogiri/xml/parse_options'
RSpec::Matchers.define :match_html do |expected|
  match do |actual|
    a = make_canonical_html(expected).to_html.gsub(/\s+/, " ").strip
    b = make_canonical_html(actual).to_html.gsub(/\s+/, " ").strip
    a.eql? b
  end

  failure_message do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n to match:\n#{expected}"
  end

  failure_message_when_negated do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n not to match:\n#{expected}"
  end

  def make_canonical_html(html)
    Nokogiri::HTML(html) { |config| config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::COMPACT }
  end

end
