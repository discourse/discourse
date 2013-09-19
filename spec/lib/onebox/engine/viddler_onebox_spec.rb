require "spec_helper"

describe Onebox::Engine::ViddlerOnebox do
  let(:link) { "http://viddler.com" }
  before do
    fake(link, response("viddler"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Viddler Demo")
    end

    it "returns video image" do
      expect(html).to include("thumbnail_2_7164f749_v2.jpg")
    end

    it "returns video description" do
      expect(html).to include("Get familiar with your Viddler account.")
    end

    it "returns video URL" do
      expect(html).to include("http://www.viddler.com/player/7164f749")
    end

    it "returns video embed code"

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
