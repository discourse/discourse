# frozen_string_literal: true

RSpec.describe Onebox::Engine::GoogleCalendarOnebox do
  describe ".===" do
    it "matches valid Google Calendar URL" do
      valid_url = URI("https://calendar.google.com/calendar/u/0/r/eventedit")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid shortened URL" do
      valid_shortened_url = URI("https://goo.gl/calendar/abcd1234")
      expect(described_class === valid_shortened_url).to eq(true)
    end

    it "does not match URL with extra domain" do
      malicious_url = URI("https://calendar.google.com.malicious.com/calendar/u/0/r/eventedit")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match URL with subdomain" do
      subdomain_url = URI("https://sub.calendar.google.com/calendar/u/0/r/eventedit")
      expect(described_class === subdomain_url).to eq(false)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://calendar.google.com/someotherpath")
      expect(described_class === invalid_path_url).to eq(false)
    end
  end
end
