require "spec_helper"

describe Onebox::Engine::ImgurImageOnebox do
  before(:all) do
    @link = "http://imgur.com/gallery/twoDTCU"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

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
