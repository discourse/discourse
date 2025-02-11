# frozen_string_literal: true

RSpec.describe Onebox::Engine::SimplecastOnebox do
  describe ".===" do
    it "matches valid Simplecast episodes URL" do
      valid_url = URI("https://simplecast.com/episodes/example-episode")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid Simplecast short URL" do
      valid_short_url = URI("https://simplecast.com/s/123abc")
      expect(described_class === valid_short_url).to eq(true)
    end

    it "matches valid Simplecast subdomain URL" do
      valid_subdomain_url = URI("https://subdomain.simplecast.com/episodes/example-episode")
      expect(described_class === valid_subdomain_url).to eq(true)
    end

    it "does not match URL with invalid path" do
      invalid_path_url = URI("https://simplecast.com/invalid/123")
      expect(described_class === invalid_path_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/episodes/example-episode")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
