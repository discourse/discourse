# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Connect do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:credential_id) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params: params, **dependencies) }

    fab!(:acting_user, :admin)
    fab!(:credential, :discourse_workflows_oauth2_credential)

    let(:params) { { credential_id: credential.id } }
    let(:dependencies) { { guardian: acting_user.guardian } }

    context "when the actor cannot manage workflows" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when the contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when the credential does not exist" do
      let(:params) { { credential_id: -1 } }

      it { is_expected.to fail_to_find_a_model(:credential) }
    end

    context "when the credential is static" do
      fab!(:credential, :discourse_workflows_credential)

      it { is_expected.to fail_a_policy(:oauth_credential) }
    end

    context "when the credential can be connected" do
      before do
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: { access_token: "access-token", token_type: "Bearer" }.to_json,
        )
      end

      it "connects the credential using the app credentials" do
        expect(result).to run_successfully
        expect(result[:credential]).to eq(credential)
        expect(credential.reload.oauth_connection).to include("status" => "connected")
        expect(credential.oauth_connection).not_to have_key("refresh_token")
      end
    end

    context "when the app credentials are rejected" do
      before do
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 400,
          body: { error: "invalid_client" }.to_json,
        )
      end

      it { is_expected.to fail_with_exception(DiscourseWorkflows::Oauth2Provider::Error) }
    end
  end
end
