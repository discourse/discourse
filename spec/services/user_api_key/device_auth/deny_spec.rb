# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Deny do
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

    it "marks the grant as denied" do
      result

      grant =
        JSON.parse(
          Discourse.redis.get(
            UserApiKey::DeviceAuth::Store.device_grant_key(device_request[:device_code]),
          ),
        )
      expect(grant["status"]).to eq("denied")
    end

    context "when the grant does not exist" do
      let(:params) { { device_code: SecureRandom.hex(32) } }

      it { is_expected.to fail_a_step(:deny_grant) }
    end
  end
end
