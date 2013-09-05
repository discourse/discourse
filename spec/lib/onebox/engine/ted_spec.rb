require "spec_helper"

describe Onebox::Engine::TedOnebox do
  let(:link) { "http://ted.com" }
  before do
    fake(link, response("ted.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns video title" do
      expect(html).to include("Eli Beer: The fastest ambulance? A motorcycle")
    end

    it "returns video photo" do
      expect(html).to include("aa8d0403aec3466d031e3e1c1605637d84d6a07d_389x292.jpg")
    end

    it "returns video description" do
      expect(html).to include("As a young EMT on a Jerusalem ambulance")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
