# frozen_string_literal: true

RSpec.describe DiscourseCalendar::Livestream::ZoomUrlParser do
  describe ".parse" do
    it "parses a standard Zoom meeting URL" do
      result = described_class.parse("https://us06web.zoom.us/j/123456789?pwd=secret")

      expect(result).to eq(
        meeting_number: "123456789",
        password: "secret",
        url: "https://us06web.zoom.us/j/123456789?pwd=secret",
      )
    end

    it "parses a Zoom webinar URL without a password" do
      result = described_class.parse("https://zoom.us/w/987654321")

      expect(result).to eq(
        meeting_number: "987654321",
        password: nil,
        url: "https://zoom.us/w/987654321",
      )
    end

    it "parses a web client URL" do
      result = described_class.parse("https://zoom.us/wc/123456789/join")

      expect(result).to include(meeting_number: "123456789")
    end

    it "ignores the case of the host" do
      result = described_class.parse("https://US06WEB.ZOOM.US/j/123456789")

      expect(result).to include(meeting_number: "123456789")
    end

    it "returns nil for hosts that only end in the Zoom domain" do
      expect(described_class.parse("https://notzoom.us/j/123456789")).to be_nil
    end

    it "returns nil for hosts that only start with the Zoom domain" do
      expect(described_class.parse("https://zoom.us.evil.com/j/123456789")).to be_nil
    end

    it "returns nil for unsupported hosts" do
      expect(described_class.parse("https://example.com/j/123456789")).to be_nil
    end

    it "returns nil for non-HTTPS URLs" do
      expect(described_class.parse("http://zoom.us/j/123456789")).to be_nil
    end

    it "returns nil when there is no supported path segment" do
      expect(described_class.parse("https://zoom.us/meeting/123456789")).to be_nil
    end

    it "returns nil when the meeting number is missing" do
      expect(described_class.parse("https://zoom.us/j/")).to be_nil
    end

    it "returns nil when the meeting number is not numeric" do
      expect(described_class.parse("https://zoom.us/j/not-a-number")).to be_nil
    end

    it "returns nil for malformed URLs" do
      expect(described_class.parse("not-a-url")).to be_nil
    end

    it "returns nil for blank URLs" do
      expect(described_class.parse(nil)).to be_nil
      expect(described_class.parse("")).to be_nil
    end
  end

  describe ".zoom_url?" do
    it "is true for a joinable Zoom URL on a vanity subdomain" do
      expect(described_class.zoom_url?("https://us06web.zoom.us/j/123456789")).to eq(true)
    end

    it "is false for a Zoom URL we cannot extract a meeting number from" do
      expect(described_class.zoom_url?("https://zoom.us/about")).to eq(false)
    end

    it "is false for a non-Zoom URL" do
      expect(described_class.zoom_url?("https://example.com/live")).to eq(false)
    end
  end
end
