require "spec_helper"

describe Onebox::Engine::ImgurImageOnebox do
  let(:link) { "http://imgur.com/gallery/twoDTCU" }

  before do
    fake(link, response("imgur_image"))
  end

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the image title" do
      expect(html).to include("My dog likes to hug me")
    end

    it "returns the image" do
      expect(html).to include("twoDTCU.jpg")
    end

    it "returns URL" do
      expect(html).to include(link)
    end
  end
end
