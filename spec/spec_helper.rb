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

  it "has implemented the data functionality" do
    expect { described_class.new(link).send(:data) }.not_to raise_error
  end


  it "correctly matches the url" do
    onebox = Onebox::Matcher.new(link).oneboxed
    expect(onebox).to be(described_class)
  end
end
