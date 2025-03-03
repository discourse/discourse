# frozen_string_literal: true

RSpec.describe Onebox::Engine::SlidesOnebox do
  let(:link) { "https://slides.com/drksephy/ecmascript-2015" }
  let(:html) { described_class.new(link).to_html }

  before { stub_request(:get, link).to_return(status: 200, body: onebox_response("slides")) }

  describe "#placeholder_html" do
    it "returns an image as the placeholder" do
      expect(Onebox.preview(link).placeholder_html).to include(
        "//s3.amazonaws.com/media-p.slid.es/thumbnails/secure/cff7c3/decks.jpg",
      )
    end
  end

  describe "#to_html" do
    it "returns iframe embed" do
      expect(html).to include(URI(link).path)
      expect(html).to include("iframe")
    end
  end

  describe ".===" do
    it "matches valid Slides URL" do
      valid_url = URI("https://slides.com/drksephy/example-slide")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with missing slide name" do
      invalid_url = URI("https://slides.com/drksephy/")
      expect(described_class === invalid_url).to eq(false)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://slides.com.malicious.com/drksephy/example-slide")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/drksephy/example-slide")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
