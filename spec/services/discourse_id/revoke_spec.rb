# frozen_string_literal: true

RSpec.describe DiscourseId::Revoke do
  describe described_class::Contract, type: :model do
    subject(:contract) { described_class.new(identifier:, timestamp:, signature:) }

    let(:identifier) { SecureRandom.hex }
    let(:signature) { SecureRandom.hex }
    let(:timestamp) { Time.current.to_i }

    it { is_expected.to validate_presence_of(:identifier) }
    it { is_expected.to validate_presence_of(:timestamp) }
    it { is_expected.to validate_presence_of(:signature) }

    context "when the timestamp is expired" do
      let(:timestamp) { Time.current.to_i - 3600 }

      it do
        is_expected.not_to allow_value(timestamp).for(:timestamp).with_message(
          "is expired: 3600 seconds old",
        )
      end
    end

    context "when the signature is not valid" do
      it do
        is_expected.not_to allow_value(signature).for(:signature).with_message(
          "is invalid for user id #{identifier}",
        )
      end
    end
  end

  describe "#call" do
    subject(:result) { described_class.call(params:) }

    fab!(:user)

    let(:params) { { identifier: uaa.provider_uid, timestamp:, signature: } }
    let(:client_id) { SiteSetting.discourse_id_client_id }
    let(:hashed_secret) { Digest::SHA256.hexdigest(SiteSetting.discourse_id_client_secret) }
    let(:identifier) { SecureRandom.hex }
    let(:provider_name) { "discourse_id" }
    let(:timestamp) { Time.current.to_i }
    let(:signature) do
      OpenSSL::HMAC.hexdigest("sha256", hashed_secret, "#{client_id}:#{identifier}:#{timestamp}")
    end
    let!(:uaa) do
      Fabricate(
        :user_associated_account,
        user:,
        provider_name: "discourse_id",
        provider_uid: identifier,
      )
    end

    before do
      SiteSetting.enable_discourse_id = true
      SiteSetting.discourse_id_client_id = SecureRandom.hex
      SiteSetting.discourse_id_client_secret = SecureRandom.hex
    end

    context "when discourse id is not properly configured" do
      before do
        SiteSetting.discourse_id_client_id = nil
        SiteSetting.discourse_id_client_secret = nil
      end

      it { is_expected.to fail_a_policy(:discourse_id_properly_configured) }
    end

    context "when contract is not valid" do
      let(:signature) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when the associated account is not found" do
      before { uaa.destroy! }

      it { is_expected.to fail_to_find_a_model(:associated_account) }
    end

    context "when everything is ok" do
      before { UserAuthToken.generate!(user_id: user.id) }

      it { is_expected.to run_successfully }

      it "destroys user auth tokens" do
        expect { result }.to change { UserAuthToken.where(user_id: user.id).count }.by(-1)
      end
    end
  end
end
