require "spec_helper"

describe Onebox::Engine::QikOnebox do
  let(:link) { "http://qik.com" }
  before do
    fake(link, response("qik.response"))
  end

  it_behaves_like "engines"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the video title" do
      expect(html).to include("20910")
    end

    it "returns the video author" do
      expect(html).to include("mitesh patel")
    end

    it "returns the video uploader photo" do
      expect(html).to include("me_large.jpg")
    end

    it "returns the video URL" do
      expect(html).to include(link)
    end

    it "returns the video embed code" do
      pending
      expect(html).to include("clsid:d27cdb6e-ae6d-11cf-96b8-444553540000")
    end
  end
end
