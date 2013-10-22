require "spec_helper"

describe Onebox::Engine::ViddlerOnebox do
  before(:all) do
    @link = "http://www.viddler.com/v/7164f749"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes still" do
      expect(html).to include("thumbnail_2_7164f749_v2.jpg")
    end

    it "includes description" do
      expect(html).to include("Get familiar with your Viddler account.")
    end

    it "includes embedded video link" do
      expect(html).to include("http://www.viddler.com/player/7164f749")
    end

    it "returns video embed code"
  end
end
