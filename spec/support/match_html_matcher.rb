require 'nokogiri/xml/parse_options'
RSpec::Matchers.define :match_html do |expected|
  match do |actual|
    a = make_canonical_html expected
    b = make_canonical_html actual
    a.to_html == b.to_html
  end

  failure_message_for_should do |actual|
    "after sanitizing for extra white space and compactness, expected #{actual} to match #{expected}"
  end

  failure_message_for_should_not do |actual|
    "after sanitizing for extra white space and compactness, expected #{actual} not to match #{expected}"
  end

  def make_canonical_html(html)
    Nokogiri::HTML(html) { |config| config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::COMPACT }
  end

end
