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
    it "includes title" do
      expect(data[:title]).not_to be_nil
    end

    it "includes link" do
      expect(data[:link]).not_to be_nil
    end

    it "includes badge" do
      expect(data[:badge]).not_to be_nil
    end

    it "includes domain" do
      expect(data[:domain]).not_to be_nil
    end
  end

  describe "to_html" do
    def value_of(key)
      CGI.escapeHTML(data[key])
    end

    it "includes subname" do
      expect(html).to include(%|<aside class="onebox #{described_class.template_name}">|)
    end

    it "includes title" do
      expect(html).to include(value_of(:title))
    end

    it "includes link" do
      expect(html).to include(%|class="link" href="#{value_of(:link)}|)
    end

    it "includes badge" do
      expect(html).to include(%|<strong class="name">#{value_of(:badge)}</strong>|)
    end

    it "includes domain" do
      expect(html).to include(%|class="domain" href="#{value_of(:domain)}|)
    end
  end
end
