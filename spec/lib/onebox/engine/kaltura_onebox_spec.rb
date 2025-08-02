# frozen_string_literal: true

RSpec.describe Onebox::Engine::KalturaOnebox do
  let(:link) { "https://videos.kaltura.com/id/0_e2ea6ygt" }

  before { stub_request(:get, link).to_return(status: 200, body: onebox_response("kaltura")) }

  shared_examples "Pulling the width and height from OpenGraph" do
    it "Pulls the width from the OG video width" do
      og_video_width = "534"
      actual_width = inspect_html_fragment(html, tag_name, "width")

      expect(actual_width).to eq og_video_width
    end

    it "Pulls the height from the OG video height" do
      og_video_height = "300"
      actual_height = inspect_html_fragment(html, tag_name, "height")

      expect(actual_height).to eq og_video_height
    end
  end

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }
    let(:tag_name) { "iframe" }

    it_behaves_like "Pulling the width and height from OpenGraph"

    it "Pulls the src from the OG view secure url" do
      og_video_secure_url =
        "https://cdnapisec.kaltura.com//p/811441/sp/81144100/embedIframeJs/uiconf_id/40430081/" \
          "partner_id/811441?iframeembed=true&playerId=kaltura_playe" \
          "r&entry_id=0_e2ea6ygt&widget_id=1_c6hc9mf5"

      actual_src = inspect_html_fragment(html, tag_name, "src")

      expect(actual_src).to eq og_video_secure_url
    end
  end

  describe "#placeholder_html" do
    let(:html) { described_class.new(link).preview_html }
    let(:tag_name) { "img" }

    it_behaves_like "Pulling the width and height from OpenGraph"

    it "Pulls the thumbnail from the OG video thumbnail" do
      og_video_thumbnail =
        "https://cdnapisec.kaltura.com/p/811441/sp/81144100/thumbnail/entry_id/0_e2ea6ygt/width/534"
      actual_thumbnail = inspect_html_fragment(html, tag_name, "src")

      expect(actual_thumbnail).to eq og_video_thumbnail
    end
  end

  describe ".===" do
    it "matches valid Kaltura URL" do
      valid_url = URI("https://cdn.kaltura.com/id/abc123")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://cdn.kaltura.com.malicious.com/id/abc123")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_path_url = URI("https://cdn.kaltura.com/id/abc123/extra")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
