require "spec_helper"

describe Onebox::Engine::WikipediaOnebox do
  before(:all) do
    @link = "http://en.wikipedia.org/wiki/Kevin_Bacon"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes article image" do
      expect(html).to include("225px-Kevin_Bacon_Comic-Con_2012.jpg")
    end

    it "includes summary" do
      expect(html).to include("Kevin Norwood Bacon (born July 8, 1958)")
    end
  end
end
