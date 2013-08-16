require "spec_helper"

describe Onebox::Engine::Wikipedia do
  describe "to_html" do
    let(:link) { "http://example.com" }
    let(:wikipedia) { described_class.new(link).to_html }

    before do
      fake(link, response("wikipedia.response"))
    end

    it "returns the product URL" do
      expect(wikipedia).to include(link)
    end

    it "returns the article title" do
      expect(wikipedia).to include("Kevin Bacon")
    end

    it "returns the article img src" do
      expect(wikipedia).to include("225px-Kevin_Bacon_Comic-Con_2012.jpg")
    end

    it "returns the article summary" do
      expect(wikipedia).to include("Kevin Norwood Bacon[1] (born July 8, 1958)")
    end
  end
end
