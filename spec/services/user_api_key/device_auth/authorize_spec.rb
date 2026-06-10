# frozen_string_literal: true

RSpec.describe UserApiKey::DeviceAuth::Authorize do
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
  let(:params) { { device_code: device_request[:device_code], user_id: user.id } }

  after { clear_user_api_key_device_auth_redis! }

  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:device_code) }
    it { is_expected.to validate_presence_of(:user_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params) }

    it { is_expected.to run_successfully }

    it "authorizes the grant and creates a user API key" do
      expect { result }.to change { UserApiKey.where(user: user).count }.by(1)

      grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])

      expect(grant).to be_authorized
      expect(grant.payload).to be_present
    end

    context "when the user does not exist" do
      let(:params) { { device_code: device_request[:device_code], user_id: 0 } }

      it { is_expected.to fail_to_find_a_model(:user) }
    end

    context "when the grant does not exist" do
      let(:params) { { device_code: SecureRandom.hex(32), user_id: user.id } }

      it { is_expected.to fail_a_step(:authorize_grant) }
    end

    context "when the grant is bound to another user" do
      let!(:other_user) { Fabricate(:user) }

      before do
        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])
        grant.bind_to_user!(other_user)
        UserApiKey::DeviceAuth::GrantStore.save!(
          grant,
          ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant.device_code),
        )
      end

      it { is_expected.to fail_a_step(:authorize_grant) }

      it "does not create a key for the current user" do
        expect { result }.not_to change { UserApiKey.where(user: user).count }
      end
    end

    context "when the grant is already authorized" do
      before { UserApiKey::DeviceAuth::Authorize.call(params: params) }

      it { is_expected.to fail_a_step(:authorize_grant) }

      it "does not create another key for the current user" do
        expect { result }.not_to change { UserApiKey.where(user: user).count }
      end
    end

    context "when the grant is denied" do
      before do
        grant = UserApiKey::DeviceAuth::GrantStore.load(device_request[:device_code])
        grant.deny!
        UserApiKey::DeviceAuth::GrantStore.save!(
          grant,
          ttl: UserApiKey::DeviceAuth::GrantStore.ttl_for_update(grant.device_code),
        )
      end

      it { is_expected.to fail_a_step(:authorize_grant) }

      it "does not create a key for the current user" do
        expect { result }.not_to change { UserApiKey.where(user: user).count }
      end
    end
  end
end
