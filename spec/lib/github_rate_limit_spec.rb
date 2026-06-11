# frozen_string_literal: true

RSpec.describe GithubRateLimit do
  let(:token) { "gh_token_123" }

  def ttl(token = nil)
    Discourse.redis.without_namespace.ttl(described_class.key(token))
  end

  describe ".key" do
    it "is per-token, and a shared bucket for unauthenticated requests" do
      expect(described_class.key(token)).to eq(
        "onebox_github_backoff_#{Digest::SHA1.hexdigest(token)}",
      )
      expect(described_class.key(nil)).to eq("onebox_github_backoff_unauthenticated")
      expect(described_class.key("")).to eq("onebox_github_backoff_unauthenticated")
    end
  end

  describe ".note_rate_limit" do
    it "backs off for the Retry-After duration" do
      described_class.note_rate_limit(token:, retry_after: 90)
      expect(described_class.backing_off?(token)).to eq(true)
      expect(ttl(token)).to be_between(1, 90)
    end

    it "backs off until x-ratelimit-reset when the remaining budget is 0" do
      described_class.note_rate_limit(token:, remaining: "0", reset_at: 10.minutes.from_now.to_i)
      expect(ttl(token)).to be_between(1, 600)
    end

    it "does nothing when there is budget left and no Retry-After" do
      described_class.note_rate_limit(token:, remaining: "57")
      expect(described_class.backing_off?(token)).to eq(false)
    end

    it "clamps the backoff to one hour" do
      described_class.note_rate_limit(token:, remaining: "0", reset_at: 10.days.from_now.to_i)
      expect(ttl(token)).to be <= 1.hour.to_i
    end

    it "is scoped per token" do
      described_class.note_rate_limit(token:, retry_after: 90)
      expect(described_class.backing_off?("other_token")).to eq(false)
      expect(described_class.backing_off?(nil)).to eq(false)
    end
  end

  describe ".note_response_headers" do
    it "reads the rate-limit headers regardless of casing" do
      described_class.note_response_headers(
        { "Retry-After" => "120", "X-RateLimit-Remaining" => "0" },
        token:,
      )
      expect(ttl(token)).to be_between(1, 120)
    end
  end

  describe ".active?" do
    it "is true while any backoff key exists" do
      expect(described_class.active?).to eq(false)
      described_class.note_rate_limit(token:, retry_after: 30)
      expect(described_class.active?).to eq(true)
    end
  end
end
