# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Poll do
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

    context "with an invalid device code" do
      let(:params) { { device_code: "invalid" } }

      it { is_expected.to run_successfully }

      it "returns expired_token" do
        expect(result[:poll_response]).to eq(status: "expired_token")
      end
    end
  end
end
