# frozen_string_literal: true

RSpec.describe Onebox::Engine::GoogleMeetOnebox do
  let(:meeting_url) { "https://meet.google.com/ezj-ptyx-gkp" }

  it "uses an icon included in the default SVG sprite" do
    aggregate_failures do
      expect(SvgSprite.search("video")).to be_present
      expect(SvgSprite.all_icons).to include("video")
    end
  end

  describe ".===" do
    it "is selected before the generic engine" do
      engine = Onebox::Matcher.new(meeting_url, { allowed_iframe_regexes: [/.*/] }).oneboxed

      expect(engine).to be(described_class)
    end

    it "matches Google Meet meeting URLs" do
      aggregate_failures do
        expect(described_class === URI("https://meet.google.com/ezj-ptyx-gkp")).to eq(true)
        expect(described_class === URI("http://meet.google.com/ezj-ptyx-gkp")).to eq(true)
        expect(described_class === URI("https://meet.google.com/ezj-ptyx-gkp/")).to eq(true)
        expect(described_class === URI("https://meet.google.com/ezj-ptyx-gkp?authuser=0")).to eq(
          true,
        )
        expect(described_class === URI("https://meet.google.com/EZJ-PTYX-GKP")).to eq(true)
        expect(described_class === URI("https://meet.google.com/lookup/team-standup_1")).to eq(true)
      end
    end

    it "rejects non-meeting URLs" do
      aggregate_failures do
        expect(described_class === URI("https://meet.google.com.evil.com/ezj-ptyx-gkp")).to eq(
          false,
        )
        expect(described_class === URI("https://sub.meet.google.com/ezj-ptyx-gkp")).to eq(false)
        expect(described_class === URI("https://meet.google.com/unsupported")).to eq(false)
        expect(described_class === URI("https://meet.google.com/new")).to eq(false)
        expect(described_class === URI("https://meet.google.com/abcdefghij")).to eq(false)
        expect(described_class === URI("https://meet.google.com/onboarding")).to eq(false)
        expect(described_class === URI("https://meet.google.com/abc-defg-hij/extra")).to eq(false)
        expect(described_class === URI("https://google.com/ezj-ptyx-gkp")).to eq(false)
      end
    end
  end

  describe "#to_html" do
    it "renders a static meeting card" do
      html = Onebox.preview(meeting_url).to_s
      document = Nokogiri::HTML5.fragment(html)
      join_link = document.at_css(".google-meet-onebox__join")

      aggregate_failures do
        expect(document.at_css("aside.onebox.googlemeet")).to be_present
        expect(document.at_css("iframe")).to be_nil
        expect(document.at_css(".google-meet-onebox__icon use")["href"]).to eq("#video")
        expect(document.at_css(".google-meet-onebox__title").text).to include("Google Meet meeting")
        expect(document.at_css(".google-meet-onebox__code-label").text).to include("Code:")
        expect(document.at_css(".google-meet-onebox__code-value").text).to eq("ezj-ptyx-gkp")
        expect(join_link["class"]).to eq("google-meet-onebox__join")
        expect(join_link.text).to include("Join meeting")
        expect(join_link["href"]).to eq(meeting_url)
        expect(html).not_to include("Google Workspace")
        expect(html).not_to include("Online web and video conferencing calls")
      end
    end

    it "escapes malicious query strings" do
      attack_payload = %("><script>alert(1)</script>)
      malicious_url = "https://meet.google.com/tiw-gooe-vbs?authuser=#{attack_payload}"
      normalized_url = UrlHelper.normalized_encode(malicious_url).to_s
      escaped_url = Onebox::Helpers.uri_encode(normalized_url)

      Oneboxer.invalidate(normalized_url)

      html = Oneboxer.onebox(malicious_url)
      document = Nokogiri::HTML5.fragment(html)

      aggregate_failures do
        expect(document.css("script")).to be_empty
        expect(html).not_to include(attack_payload)
        expect(document.at_css("aside.onebox.googlemeet")["data-onebox-src"]).to eq(escaped_url)
        expect(document.css("a").map { |link| link["href"] }.uniq).to eq([escaped_url])
        expect(document.at_css(".google-meet-onebox__code-value").text).to eq("tiw-gooe-vbs")
      end
    end

    it "keeps the original meeting URL when Google redirects" do
      redirected_url =
        "https://meet.google.com/unsupported?meetingCode=tiw-gooe-vbs&ref=https://meet.google.com/tiw-gooe-vbs"
      head_stub =
        stub_request(:head, "https://meet.google.com/tiw-gooe-vbs").to_return(
          status: 302,
          body: "",
          headers: {
            "location" => redirected_url,
          },
        )
      redirect_stub = stub_request(:any, redirected_url)

      Oneboxer.invalidate("https://meet.google.com/tiw-gooe-vbs")

      html = Oneboxer.external_onebox("https://meet.google.com/tiw-gooe-vbs")[:onebox]
      document = Nokogiri::HTML5.fragment(html)

      aggregate_failures do
        expect(document.at_css("aside.onebox.googlemeet")).to be_present
        expect(document.at_css(".google-meet-onebox__code-value").text).to eq("tiw-gooe-vbs")
        expect(document.at_css(".google-meet-onebox__join")["href"]).to eq(
          "https://meet.google.com/tiw-gooe-vbs",
        )
        expect(html).not_to include("/unsupported")
        expect(head_stub).not_to have_been_requested
        expect(redirect_stub).not_to have_been_requested
      end
    end

    it "normalizes uppercase meeting codes" do
      html = Onebox.preview("https://meet.google.com/EZJ-PTYX-GKP").to_s
      document = Nokogiri::HTML5.fragment(html)

      expect(document.at_css(".google-meet-onebox__code-value").text).to eq("ezj-ptyx-gkp")
    end

    it "renders lookup links without a meeting code" do
      html = Onebox.preview("https://meet.google.com/lookup/team-standup_1").to_s
      document = Nokogiri::HTML5.fragment(html)

      aggregate_failures do
        expect(document.at_css("aside.onebox.googlemeet")).to be_present
        expect(document.at_css(".google-meet-onebox__code-value")).to be_nil
        expect(document.at_css(".google-meet-onebox__description").text).to include(
          "Open this Google Meet link to join the call.",
        )
      end
    end
  end

  describe "#inline_data" do
    it "returns a concise inline onebox title" do
      expect(Oneboxer.inline_data_for(meeting_url)).to eq(title: "Google Meet meeting")
    end
  end
end
