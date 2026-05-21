# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::CodeRegistry do
  let(:device_code) { SecureRandom.hex(32) }
  let(:grant) do
    UserApiKey::DeviceAuth::Grant.new(
      status: :pending,
      device_code: device_code,
      user_code: "ABCD-2345",
      request_token: "abcdefgh",
    )
  end

  after { clear_user_api_key_device_auth_redis! }

  describe ".load_by_user_code" do
    it "loads through the user-code index" do
      UserApiKey::DeviceAuth::GrantStore.save!(grant, ttl: 1.minute)
      Discourse.redis.setex(described_class.user_code_key("ABCD-2345"), 1.minute, device_code)

      expect(described_class.load_by_user_code("ABCD-2345")).to eq(grant)
    end

    it "deletes stale user-code indexes" do
      Discourse.redis.setex(described_class.user_code_key("ABCD-2345"), 1.minute, device_code)

      expect(described_class.load_by_user_code("ABCD-2345")).to be_nil
      expect(Discourse.redis.get(described_class.user_code_key("ABCD-2345"))).to be_nil
    end
  end

  describe ".load_by_request_token" do
    it "loads through the request-token index" do
      UserApiKey::DeviceAuth::GrantStore.save!(grant, ttl: 1.minute)
      Discourse.redis.setex(described_class.request_token_key("abcdefgh"), 1.minute, device_code)

      expect(described_class.load_by_request_token("abcdefgh")).to eq(grant)
    end

    it "deletes stale request-token indexes" do
      Discourse.redis.setex(described_class.request_token_key("abcdefgh"), 1.minute, device_code)

      expect(described_class.load_by_request_token("abcdefgh")).to be_nil
      expect(Discourse.redis.get(described_class.request_token_key("abcdefgh"))).to be_nil
    end

    it "rejects invalid request-token formats" do
      expect(described_class.load_by_request_token("not valid")).to be_nil
    end
  end

  describe ".user_code_matches_grant?" do
    it "checks the normalized user-code index against the grant" do
      Discourse.redis.setex(described_class.user_code_key("ABCD-2345"), 1.minute, device_code)

      expect(described_class.user_code_matches_grant?("abcd2345", grant)).to eq(true)
      expect(described_class.user_code_matches_grant?("WXYZ6789", grant)).to eq(false)
    end
  end

  describe ".delete_indexes_for" do
    it "removes user-code and request-token indexes" do
      Discourse.redis.setex(described_class.user_code_key("ABCD-2345"), 1.minute, device_code)
      Discourse.redis.setex(described_class.request_token_key("abcdefgh"), 1.minute, device_code)

      described_class.delete_indexes_for(grant)

      expect(Discourse.redis.get(described_class.user_code_key("ABCD-2345"))).to be_nil
      expect(Discourse.redis.get(described_class.request_token_key("abcdefgh"))).to be_nil
    end
  end

  describe ".reserve_for" do
    it "reserves a user code and request token for the device" do
      codes = described_class.reserve_for(device_code)

      expect(codes.user_code).to match(/\A[A-Z2-9]{4}-[A-Z2-9]{4}\z/)
      expect(codes.request_token).to match(UserApiKey::DeviceAuth::DEVICE_REQUEST_TOKEN_REGEX)
      expect(Discourse.redis.get(described_class.user_code_key(codes.user_code))).to eq(device_code)
      expect(Discourse.redis.get(described_class.request_token_key(codes.request_token))).to eq(
        device_code,
      )
    end
  end
end
