# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::UserActivation do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:session) { {} }
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

  after { clear_user_api_key_device_auth_redis! }

  describe "#preview_request_token" do
    it "does not preview grants without a user" do
      result =
        described_class.new(
          user: nil,
          session: session,
          request_id: "request-id",
        ).preview_request_token(device_request[:request_token])

      expect(result.status).to eq(:expired_code)
      expect(result.debug_reason).to eq("user_missing")
    end
  end
end
