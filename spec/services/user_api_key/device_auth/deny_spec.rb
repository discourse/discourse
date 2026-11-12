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

      grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])

      expect(grant).to be_denied
    end

    context "when the grant does not exist" do
      let(:params) { { device_code: SecureRandom.hex(32) } }

      it { is_expected.to fail_a_step(:deny_grant) }
    end

    context "when the grant is already denied" do
      before do
        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])
        grant.deny!
        UserApiKey::DeviceAuth::GrantStore.save!(
          grant,
          ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant.device_code),
        )
      end

      it { is_expected.to run_successfully }

      it "keeps the grant denied" do
        result

        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])

        expect(grant).to be_denied
      end
    end

    context "when the grant is authorized" do
      fab!(:user)

      before do
        UserApiKey::DeviceAuth::Authorize.call(
          params: {
            device_code: device_request[:device_code],
            user_id: user.id,
          },
        )
      end

      it { is_expected.to fail_a_step(:deny_grant) }
    end
  end
end
