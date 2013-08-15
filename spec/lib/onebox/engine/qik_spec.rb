require "spec_helper"

describe Onebox::Engine::Qik do
  describe "#to_html" do
    let(:link) { "http://qik.com" }
    let(:qik) { described_class.new(response("qik.response"), link).to_html }

    it "returns the video title" do
      expect(qik).to include("20910")
    end

    it "returns the video author" do
      expect(qik).to include("mitesh patel")
    end

    it "returns the video uploader photo" do
      expect(qik).to include("me_large.jpg")
    end

    it "returns the video URL" do
      expect(qik).to include(link)
    end

    it "returns the video embed code" do
      pending
      expect(qik).to include("clsid:d27cdb6e-ae6d-11cf-96b8-444553540000")
    end
  end
end
