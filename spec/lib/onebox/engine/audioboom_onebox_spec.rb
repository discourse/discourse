# frozen_string_literal: true

RSpec.describe Onebox::Engine::AudioboomOnebox do
  describe ".===" do
    it "matches valid Audioboom URL" do
      valid_url = URI("https://audioboom.com/posts/12345")
      expect(described_class === valid_url).to eq(true)
    end

    it "does not match invalid domain" do
      invalid_url = URI("https://audioboom.com.malicious.com/posts/12345")
      expect(described_class === invalid_url).to eq(false)
    end

    it "does not match invalid path" do
      invalid_url = URI("https://audioboom.com/somethingelse/12345")
      expect(described_class === invalid_url).to eq(false)
    end

    it "does not match unrelated URL" do
      unrelated_url = URI("https://example.com/posts/12345")
      expect(described_class === unrelated_url).to eq(false)
    end
  end
end
