require "spec_helper"

describe Onebox::Preview::Qik do
  describe "#to_html" do
    let(:link) { "http://qik.com" }

    it "returns the video title" do
      qik = described_class.new(response("qik.response"), link)
      expect(qik.to_html).to include("20910\n\nBy mitesh patel")
    end

    it "returns the video uploader photo" do
      qik = described_class.new(response("qik.response"), link)
      expect(qik.to_html).to include("http://qik-production.s3.amazonaws.com/photos/705975/me_large.jpg")
    end

    it "returns the video URL" do
      qik = described_class.new(response("qik.response"), link)
      expect(qik.to_html).to include(link)
    end

  end
end
