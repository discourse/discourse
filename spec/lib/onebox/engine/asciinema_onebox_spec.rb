# frozen_string_literal: true

RSpec.describe Onebox::Engine::AsciinemaOnebox do
  describe ".===" do
    it "matches valid Asciinema URL" do
      valid_url = URI("https://asciinema.org/a/abc123")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match invalid domain" do
      invalid_url = URI("https://asciinema.org.malicious.com/a/abc123")
      expect(described_class === invalid_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/a/abc123")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
