# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Poll do
  fab!(:user)

  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:device_request) do
    create_user_api_key_device_auth_request!(
      params: {
        nonce: "nonce",
        scopes: "read",
        client_id: "device-client",
        application_name: "Device Client",
        public_key: key.public_key.to_pem,
      },
    )
  end
  let(:params) { { device_code: device_request[:device_code] } }

  after { clear_user_api_key_device_auth_redis! }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:device_code) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params) }

    it { is_expected.to run_successfully }

    it "returns authorization_pending for a pending grant" do
      expect(result[:poll_response]).to eq(status: "authorization_pending")
    end

    context "with an authorized grant" do
      before do
        UserApiKey::DeviceAuth::Authorize.call(
          params: {
            device_code: device_request[:device_code],
            user_id: user.id,
          },
        )
      end

      it "returns the payload only once" do
        expect(result[:poll_response]).to include(status: "authorized", payload: be_present)
        expect(described_class.call(params: params)[:poll_response]).to eq(status: "expired_token")
      end

      it "returns a retryable response while the authorized grant is locked" do
        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])
        UserApiKey::DeviceAuth::GrantStore.save!(
          grant,
          ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(device_request[:device_code]),
        )
        Discourse.redis.setex(
          UserApiKey::DeviceAuth::GrantStore.lock_key(device_request[:device_code]),
          UserApiKey::DeviceAuth::DEVICE_AUTHORIZATION_LOCK_TTL.to_i,
          SecureRandom.hex,
        )

        expect(result[:poll_response]).to eq(status: "authorization_pending")
        Discourse.redis.del(
          UserApiKey::DeviceAuth::GrantStore.lock_key(device_request[:device_code]),
        )
        expect(described_class.call(params: params)[:poll_response]).to include(
          status: "authorized",
          payload: be_present,
        )
      end
    end

    context "with a denied grant" do
      before { UserApiKey::DeviceAuth::Deny.call(params: params) }

      it "returns access_denied" do
        expect(result[:poll_response]).to eq(status: "access_denied")
      end
    end

    context "with an invalid device code" do
      let(:params) { { device_code: "invalid" } }

      it { is_expected.to run_successfully }

      it "returns expired_token" do
        expect(result[:poll_response]).to eq(status: "expired_token")
      end
    end
  end
end
