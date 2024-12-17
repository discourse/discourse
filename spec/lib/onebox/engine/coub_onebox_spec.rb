# frozen_string_literal: true

RSpec.describe Onebox::Engine::CoubOnebox do
  describe ".matches_regexp" do
    it "matches valid coub URL" do
      valid_url = URI("https://coub.com/view/12345")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match malicious URL with valid domain as part of another domain" do
      malicious_url = URI("https://coub.com.malicious.com/view/12345")
      expect(described_class === malicious_url).to eq(false)
    end
  end
end
