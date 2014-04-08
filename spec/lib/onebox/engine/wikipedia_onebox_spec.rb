require "spec_helper"

describe Onebox::Engine::WikipediaOnebox do
  before(:all) do
    @link = "http://en.wikipedia.org/wiki/Billy_Jack"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes article image" do
      expect(html).to include("Billy_Jack_poster.jpg")
    end

    it "includes summary" do
      expect(html).to include("Billy Jack is a 1971 action/drama")
    end
  end
end
