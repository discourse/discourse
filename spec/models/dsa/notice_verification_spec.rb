# frozen_string_literal: true

RSpec.describe Dsa::NoticeVerification do
  let(:email) { "alex@example.com" }
  let(:token) { described_class.create(email) }
  let(:code) { described_class.find(token)[:code] }

  describe ".create" do
    it "stores a six digit email code for thirty minutes" do
      verification = described_class.find(token)

      expect(token).to match(/\A[0-9a-f]{64}\z/)
      expect(verification[:email]).to eq(email)
      expect(verification[:code]).to match(/\A[0-9]{6}\z/)
      expect(verification.keys).to contain_exactly(:email, :code)
      expect(Discourse.redis.ttl("dsa-notice-verification:#{token}")).to be_within(5.seconds).of(
        30.minutes.to_i,
      )
    end
  end

  describe ".find" do
    it "returns a pending verification without consuming it" do
      verification = described_class.find(token)

      expect(described_class.find(token)).to eq(verification)
    end

    it "returns no verification for an unknown token" do
      expect(described_class.find("a" * 64)).to be_nil
    end
  end

  describe ".verify" do
    it "marks the email verified without extending its lifetime" do
      verification_code = code

      Discourse.redis.expire("dsa-notice-verification:#{token}", 1200)

      expect(described_class.verify(token:, email:, code: verification_code)).to eq(email:)
      expect(described_class.find(token)).to eq(email:, verified: true)
      expect(Discourse.redis.ttl("dsa-notice-verification:#{token}")).to be_within(5.seconds).of(
        1200,
      )
    end

    it "keeps a code available after an incorrect attempt" do
      verification_code = code
      wrong_code = verification_code == "123456" ? "654321" : "123456"

      expect(described_class.verify(token:, email:, code: wrong_code)).to be_nil
      expect(described_class.verify(token:, email:, code: verification_code)).to eq(email:)
    end

    it "rejects a code presented for a different email" do
      expect(described_class.verify(token:, email: "other@example.com", code:)).to be_nil
    end

    it "limits a verification to five attempts" do
      RateLimiter.enable
      verification_code = code
      wrong_code = verification_code == "123456" ? "654321" : "123456"
      5.times { described_class.verify(token:, email:, code: wrong_code) }

      expect do described_class.verify(token:, email:, code: verification_code) end.to raise_error(
        RateLimiter::LimitExceeded,
      )
    end
  end

  describe ".consume" do
    it "accepts a verified email only once" do
      described_class.verify(token:, email:, code:)

      expect(described_class.consume(token:, email:)).to eq(email:)
      expect(described_class.consume(token:, email:)).to be_nil
      expect(described_class.find(token)).to be_nil
    end

    it "rejects an email while its code is still pending" do
      expect(described_class.consume(token:, email:)).to be_nil
      expect(described_class.find(token)).to include(:code)
    end

    it "rejects a verified token presented for another email" do
      described_class.verify(token:, email:, code:)

      expect(described_class.consume(token:, email: "other@example.com")).to be_nil
      expect(described_class.consume(token:, email:)).to eq(email:)
    end
  end
end
