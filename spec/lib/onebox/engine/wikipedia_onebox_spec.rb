require "spec_helper"

describe Onebox::Engine::WikipediaOnebox do
  let(:link) { "http://en.wikipedia.org/wiki/Kevin_Bacon" }
  before do
    fake(link, response("wikipedia"))
  end

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the product URL" do
      expect(html).to include(link)
    end

    it "returns the article title" do
      expect(html).to include("Kevin Bacon")
    end

    it "returns the article img src" do
      expect(html).to include("225px-Kevin_Bacon_Comic-Con_2012.jpg")
    end

    it "returns the article summary" do
      expect(html).to include("Kevin Norwood Bacon[1] (born July 8, 1958)")
    end
  end
end
