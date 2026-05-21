# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::GrantStore do
  let(:device_code) { SecureRandom.hex(32) }
  let(:grant) { { "status" => "pending", "device_code" => device_code } }

  after { clear_user_api_key_device_auth_redis! }

  describe ".save! and .load" do
    it "stores and loads grants" do
      described_class.save!(grant, ttl: 1.minute)

      expect(described_class.load(device_code)).to eq(grant)
    end

    it "ignores malformed device codes" do
      expect(described_class.load("invalid")).to be_nil
    end
  end

  describe ".with_lock!" do
    it "runs while holding the grant lock" do
      expect { |block| described_class.with_lock!(device_code, &block) }.to yield_control
    end

    it "raises when the lock is already held" do
      Discourse.redis.setex(
        described_class.lock_key(device_code),
        UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
        SecureRandom.hex,
      )

      expect { described_class.with_lock!(device_code) }.to raise_error(Discourse::InvalidAccess)
    end
  end

  describe ".clear!" do
    it "removes only device auth keys" do
      described_class.save!(grant, ttl: 1.minute)
      Discourse.redis.setex("unrelated", 1.minute, "value")

      described_class.clear!

      expect(described_class.load(device_code)).to be_nil
      expect(Discourse.redis.get("unrelated")).to eq("value")
    ensure
      Discourse.redis.del("unrelated")
    end
  end
end
