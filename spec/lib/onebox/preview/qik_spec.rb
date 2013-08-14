require "spec_helper"

describe Onebox::Preview::Qik do
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
  end
end
