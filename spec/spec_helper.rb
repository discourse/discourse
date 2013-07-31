require "coveralls"
Coveralls.wear! do
  add_filter "/spec/"
end

require "rspec"
require "pry"
require "fakeweb"
require "discourse-oneboxer"
require "nokogiri/xml/parse_options"
require 'mocha/api'

require_relative "support/html_spec_helper"

module SpecHelper
  def fixture_file(path)
    File.read(File.join("spec", "fixtures", path))
  end
end

RSpec.configure do |config|
  config.include SpecHelper
  config.include HTMLSpecHelper
end

RSpec::Matchers.define :match_html do |expected|
  match do |actual|
    a = make_canonical_html(expected).to_html.gsub("\r\n", "\n")
    b = make_canonical_html(actual).to_html.gsub("\r\n", "\n")
    a == b
  end

  failure_message_for_should do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual.gsub("\r\n", "\n").inspect}\n to match:\n#{expected.gsub("\r\n", "\n").inspect}"
  end

  failure_message_for_should_not do |actual|
    "after sanitizing for extra white space and compactness, expected:\n#{actual}\n not to match:\n#{expected}"
  end

  def make_canonical_html(html)
    Nokogiri::HTML(html) do |config|
      config.options = Nokogiri::XML::ParseOptions::NOBLANKS | Nokogiri::XML::ParseOptions::COMPACT
    end
  end
end
