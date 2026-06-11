# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::CreateRequest do
  let(:key) { OpenSSL::PKey::RSA.new(2048) }
  let(:public_key) { key.public_key.to_pem }
  let(:params) do
    {
      nonce: "nonce",
      scopes: "read",
      client_id: "device-client",
      application_name: "Device Client",
      public_key: public_key,
    }
  end

  after { clear_user_api_key_device_auth_redis! }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:nonce) }
    it { is_expected.to validate_presence_of(:scopes) }
    it { is_expected.to validate_presence_of(:client_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params) }

    it { is_expected.to run_successfully }

    it "stores a pending device grant" do
      device_request = result[:device_request]

      expect(device_request[:device_code]).to match(UserApiKey::DeviceAuth::DEVICE_CODE_REGEX)
      expect(device_request[:request_token]).to match(
        UserApiKey::DeviceAuth::DEVICE_REQUEST_TOKEN_REGEX,
      )

      grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])

      expect(grant).to be_pending
      expect(grant.application_name).to eq("Device Client")
      expect(grant).to be_unregistered_client
    end

    context "with missing required parameters" do
      let(:params) { { scopes: "read", client_id: "device-client" } }

      it { is_expected.to fail_a_contract }
    end

    context "when application metadata is missing" do
      let(:params) { super().except(:application_name) }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }
    end

    context "when the requested expiry is invalid" do
      let(:params) { super().merge(expires_in_seconds: 10.years.to_i) }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }

      it "records the validation exception" do
        expect(result["result.try.default"].exception).to be_a(Discourse::InvalidParameters)
      end
    end

    context "when the requested expiry is not numeric" do
      let(:params) { super().merge(expires_in_seconds: "abc") }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }
    end

    context "when the requested expiry is too long" do
      let(:params) { super().merge(expires_in_seconds: "1" * 1_000) }

      it { is_expected.to fail_with_exception(Discourse::InvalidParameters) }
    end

    context "with a registered client" do
      let!(:client) do
        UserApiKeyClient.create!(
          client_id: "device-client",
          application_name: "Stored Client Name",
          public_key: public_key,
        )
      end

      let(:params) do
        super().merge(
          application_name: "Spoofed Client Name",
          public_key: OpenSSL::PKey::RSA.new(2048).public_key.to_pem,
        )
      end

      it "uses trusted metadata from the registered client" do
        device_request = result[:device_request]
        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])

        expect(grant.application_name).to eq("Stored Client Name")
        expect(grant.public_key).to eq(public_key)
        expect(grant).not_to be_unregistered_client
      end
    end
  end
end
