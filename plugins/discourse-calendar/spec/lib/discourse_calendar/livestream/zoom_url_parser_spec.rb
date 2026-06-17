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

    it "returns nil for unsupported hosts" do
      expect(described_class.parse("https://example.com/j/123456789")).to be_nil
    end

    it "returns nil for malformed URLs" do
      expect(described_class.parse("not-a-url")).to be_nil
    end
  end
end
