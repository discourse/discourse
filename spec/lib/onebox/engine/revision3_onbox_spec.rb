require "spec_helper"

describe Onebox::Engine::Revision3Onebox do
  let(:link) { "http://revision3.com" }
  before do
    fake(link, response("revision3.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Blue Shark Bites Diver&#39;s Arm")
    end

    it "returns video image" do
      expect(html).to include("discoverysharks--0029--blue-sharks--medium.thumb.jpg")
    end

    it "returns video description" do
      expect(html).to include("Blue Sharks swimming and eating in the open ocean.")
    end

    it "returns video URL" do
      expect(html).to include("https://revision3.com/player-v22668")
    end

    it "returns video embed code"

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
