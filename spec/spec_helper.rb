require "coveralls"
Coveralls.wear! do
  add_filter "/spec/"
end

require "rspec"
require "pry"
require "fakeweb"
require "onebox"
require 'mocha/api'

require_relative "support/html_spec_helper"

RSpec.configure do |config|
  config.include HTMLSpecHelper
end

shared_examples_for "an engine" do
  it "has engine behavior" do
    expect(described_class.private_instance_methods).to include(:data, :record, :raw)
  end

  it "correctly matches the url" do
    onebox = Onebox::Matcher.new(link).oneboxed
    expect(onebox).to be(described_class)
  end

  describe "#data" do
    it "has a title" do
      expect(data[:title]).not_to be_nil
    end

    it "has a link" do
      expect(data[:link]).not_to be_nil
    end

    it "has a badge" do
      expect(data[:badge]).not_to be_nil
    end

    it "has a domain" do
      expect(data[:domain]).not_to be_nil
    end
  end

  describe "to_html" do
    it "has the title" do
      expect(html).to include(data[:title])
    end
  end
end
