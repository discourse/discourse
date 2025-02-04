# frozen_string_literal: true

RSpec.describe Onebox::Engine::ReplitOnebox do
  describe ".===" do
    it "matches valid Replit URL" do
      valid_url = URI("https://replit.com/@username/project-name")
      expect(described_class === valid_url).to eq(true)
    end

    it "matches valid repl.it URL" do
      valid_url_repl = URI("https://repl.it/@username/project-name")
      expect(described_class === valid_url_repl).to eq(true)
    end

    it "does not match URL with valid domain as part of another domain" do
      malicious_url = URI("https://replit.com.malicious.com/@username/project-name")
      expect(described_class === malicious_url).to eq(false)
    end

    it "does not match unrelated domain" do
      unrelated_url = URI("https://example.com/@username/project-name")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
