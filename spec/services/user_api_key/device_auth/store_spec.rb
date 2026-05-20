# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Store do
  let(:device_code) { SecureRandom.hex(32) }
  let(:grant) do
    {
      "status" => "pending",
      "device_code" => device_code,
      "user_code" => "ABCD-2345",
      "request_token" => "abcdefgh",
    }
  end

  after { clear_user_api_key_device_auth_redis! }

  describe ".save! and .load_by_device_code" do
    it "stores and loads grants" do
      described_class.save!(device_code, grant, ttl: 1.minute)

      expect(described_class.load_by_device_code(device_code)).to eq(grant)
    end

    it "ignores malformed device codes" do
      expect(described_class.load_by_device_code("invalid")).to be_nil
    end
  end

  describe ".load_by_user_code" do
    it "loads through the user-code index" do
      described_class.save!(device_code, grant, ttl: 1.minute)
      Discourse.redis.setex(
        described_class.device_user_code_key("ABCD-2345"),
        1.minute,
        device_code,
      )

      expect(described_class.load_by_user_code("ABCD-2345")).to eq(grant)
    end

    it "deletes stale user-code indexes" do
      Discourse.redis.setex(
        described_class.device_user_code_key("ABCD-2345"),
        1.minute,
        device_code,
      )

      expect(described_class.load_by_user_code("ABCD-2345")).to be_nil
      expect(Discourse.redis.get(described_class.device_user_code_key("ABCD-2345"))).to be_nil
    end
  end

  describe ".load_by_request_token" do
    it "loads through the request-token index" do
      described_class.save!(device_code, grant, ttl: 1.minute)
      Discourse.redis.setex(described_class.device_request_key("abcdefgh"), 1.minute, device_code)

      expect(described_class.load_by_request_token("abcdefgh")).to eq(grant)
    end

    it "rejects invalid request-token formats" do
      expect(described_class.load_by_request_token("not valid")).to be_nil
    end
  end

  describe ".delete_indexes" do
    it "removes user-code and request-token indexes" do
      Discourse.redis.setex(
        described_class.device_user_code_key("ABCD-2345"),
        1.minute,
        device_code,
      )
      Discourse.redis.setex(described_class.device_request_key("abcdefgh"), 1.minute, device_code)

      described_class.delete_indexes(grant)

      expect(Discourse.redis.get(described_class.device_user_code_key("ABCD-2345"))).to be_nil
      expect(Discourse.redis.get(described_class.device_request_key("abcdefgh"))).to be_nil
    end
  end

  describe ".with_grant_lock!" do
    it "runs while holding the grant lock" do
      expect { |block| described_class.with_grant_lock!(device_code, &block) }.to yield_control
    end

    it "raises when the lock is already held" do
      Discourse.redis.setex(
        described_class.device_authorization_lock_key(device_code),
        UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
        SecureRandom.hex,
      )

      expect { described_class.with_grant_lock!(device_code) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end
  end

  describe ".reserve_user_code!" do
    it "reserves a user code for the device" do
      user_code = described_class.reserve_user_code!(device_code)

      expect(user_code).to match(/\A[A-Z2-9]{4}-[A-Z2-9]{4}\z/)
      expect(Discourse.redis.get(described_class.device_user_code_key(user_code))).to eq(
        device_code,
      )
    end
  end

  describe ".clear!" do
    it "removes only device auth keys" do
      described_class.save!(device_code, grant, ttl: 1.minute)
      Discourse.redis.setex("unrelated", 1.minute, "value")

      described_class.clear!

      expect(described_class.load_by_device_code(device_code)).to be_nil
      expect(Discourse.redis.get("unrelated")).to eq("value")
    ensure
      Discourse.redis.del("unrelated")
    end
  end
end
