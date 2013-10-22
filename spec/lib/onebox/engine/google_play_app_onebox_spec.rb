require "spec_helper"

describe Onebox::Engine::GooglePlayAppOnebox do
  before(:all) do
    @link = "https://play.google.com/store/apps/details?id=com.hulu.plus&hl=en"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "has developer" do
      expect(html).to include("Hulu")
    end

    it "has image" do
      expect(html).to include("JH08z41G8hlCw=w300-rw")
    end

    it "has description" do
      expect(html).to include("Instantly watch current TV shows")
    end

    it "has price" do
      expect(html).to include("Free")
    end
  end
end
