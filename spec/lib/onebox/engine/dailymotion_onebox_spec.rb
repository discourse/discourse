require "spec_helper"

describe Onebox::Engine::DailymotionOnebox do
  before(:all) do
    @link = "http://dailymotion.com"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("526x297-bxE.jpg")
    end

    it "includes description" do
      expect(html).to include("Vibrez au son de l&#39;electro-pop des Irlandais de Two Door Cinema Club,")
    end

    it "includes embedded video link" do
      expect(html).to include("http://www.dailymotion.com/swf/video/x12h020?autoPlay=1")
    end

    it "includes embed code"
  end
end
