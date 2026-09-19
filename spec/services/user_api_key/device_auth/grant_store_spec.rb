# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::GrantStore do
  let(:device_code) { SecureRandom.hex(32) }
  let(:grant) { UserApiKey::DeviceAuth::Grant.new(status: :pending, device_code: device_code) }

  after { clear_user_api_key_device_auth_redis! }

  describe ".save! and .load" do
    it "stores and loads grants" do
      described_class.save!(grant, ttl: 1.minute)

      expect(described_class.load(device_code)).to eq(grant)
    end

    it "ignores malformed device codes" do
      expect(described_class.load("invalid")).to be_nil
    end

    it "loads serialized grant JSON with string keys" do
      Discourse.redis.setex(
        described_class.grant_key(device_code),
        1.minute,
        {
          "status" => "pending",
          "device_code" => device_code,
          "user_code" => "ABCD-2345",
          "request_token" => "abcdefgh",
          "authorizing_user_id" => 12,
          "authorizing_username" => "authorizer",
          "authorizing_at" => Time.zone.now.iso8601,
        }.to_json,
      )

      loaded_grant = described_class.load(device_code)

      expect(loaded_grant).to be_pending
      expect(loaded_grant.device_code).to eq(device_code)
      expect(loaded_grant.user_code).to eq("ABCD-2345")
      expect(loaded_grant.request_token).to eq("abcdefgh")
      expect(loaded_grant.authorizing_user_id).to eq(12)
    end

    it "loads authorized and denied serialized grants" do
      authorized_device_code = SecureRandom.hex(32)
      denied_device_code = SecureRandom.hex(32)
      Discourse.redis.setex(
        described_class.grant_key(authorized_device_code),
        1.minute,
        {
          "status" => "authorized",
          "device_code" => authorized_device_code,
          "payload" => "encrypted-payload",
          "authorized_at" => Time.zone.now.iso8601,
        }.to_json,
      )
      Discourse.redis.setex(
        described_class.grant_key(denied_device_code),
        1.minute,
        {
          "status" => "denied",
          "device_code" => denied_device_code,
          "denied_at" => Time.zone.now.iso8601,
        }.to_json,
      )

      expect(described_class.load(authorized_device_code)).to be_authorized
      expect(described_class.load(authorized_device_code).payload).to eq("encrypted-payload")
      expect(described_class.load(denied_device_code)).to be_denied
    end

    it "rejects invalid serialized grants" do
      described_class.save!(grant, ttl: 1.minute)
      Discourse.redis.setex(described_class.grant_key(device_code), 1.minute, [].to_json)

      expect(described_class.load(device_code)).to be_nil
    end

    it "rejects serialized grants with unknown fields" do
      Discourse.redis.setex(
        described_class.grant_key(device_code),
        1.minute,
        { status: "pending", device_code: device_code, unexpected: "value" }.to_json,
      )

      expect(described_class.load(device_code)).to be_nil
    end

    it "rejects grants with mismatched device codes" do
      Discourse.redis.setex(
        described_class.grant_key(device_code),
        1.minute,
        { status: "pending", device_code: SecureRandom.hex(32) }.to_json,
      )

      expect(described_class.load(device_code)).to be_nil
    end
  end

  describe ".consume_authorized" do
    it "atomically removes and returns an authorized grant" do
      authorized_grant =
        UserApiKey::DeviceAuth::Grant.new(
          status: :authorized,
          device_code: device_code,
          payload: "encrypted-payload",
        )
      described_class.save!(authorized_grant, ttl: 1.minute)

      expect(described_class.consume_authorized(device_code)).to eq(authorized_grant)
      expect(described_class.consume_authorized(device_code)).to be_nil
      expect(described_class.load(device_code)).to be_nil
    end

    it "returns a locked sentinel when the lock is held" do
      authorized_grant =
        UserApiKey::DeviceAuth::Grant.new(
          status: :authorized,
          device_code: device_code,
          payload: "encrypted-payload",
        )
      described_class.save!(authorized_grant, ttl: 1.minute)
      Discourse.redis.setex(
        described_class.lock_key(device_code),
        UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
        SecureRandom.hex,
      )

      expect(described_class.consume_authorized(device_code)).to eq(described_class::CONSUME_LOCKED)
      expect(described_class.load(device_code)).to eq(authorized_grant)
    end

    it "does not consume pending grants" do
      described_class.save!(grant, ttl: 1.minute)

      expect(described_class.consume_authorized(device_code)).to be_nil
      expect(described_class.load(device_code)).to eq(grant)
    end
  end

  describe ".with_lock!" do
    it "runs while holding the grant lock" do
      expect { |block| described_class.with_lock!(device_code, &block) }.to yield_control
    end

    it "releases the owned lock after running" do
      described_class.with_lock!(device_code) do
        expect(Discourse.redis.get(described_class.lock_key(device_code))).to be_present
      end

      expect(Discourse.redis.get(described_class.lock_key(device_code))).to be_nil
    end

    it "raises when the lock is already held" do
      Discourse.redis.setex(
        described_class.lock_key(device_code),
        UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
        SecureRandom.hex,
      )

      expect { described_class.with_lock!(device_code) }.to raise_error(Discourse::InvalidAccess)
    end

    it "does not release a lock claimed by another token" do
      replacement_token = SecureRandom.hex

      described_class.with_lock!(device_code) do
        Discourse.redis.set(described_class.lock_key(device_code), replacement_token)
      end

      expect(Discourse.redis.get(described_class.lock_key(device_code))).to eq(replacement_token)
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
