# frozen_string_literal: true

require "onebox_helper"

describe Onebox::Engine::GoogleDocsOnebox do
  before(:all) do
    @link = "https://docs.google.com/document/d/DOC_KEY/pub"
    fake(@link, response("googledocs"))
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "has title" do
      expect(html).to include("Lorem Ipsum!")
    end

    it "has description" do
      expect(html).to include("Lorem Ipsum  Lorem ipsum dolor sit amet, consectetur adipiscing elit")
    end

    it "has icon" do
      expect(html).to include("googledocs-onebox-logo g-docs-logo")
    end
  end
end
