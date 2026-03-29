# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:credential_type) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) do
      {
        name: "My webhook auth",
        credential_type: "basic_auth",
        data: {
          user: "admin",
          password: "secret123",
        },
      }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    before do
      DiscourseWorkflows::Registry.register_credential_type(
        DiscourseWorkflows::CredentialTypes::BasicAuth,
      )
    end

    context "when contract is invalid" do
      let(:params) { { name: nil, credential_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when credential_type is not registered" do
      let(:params) { super().merge(credential_type: "unknown_type") }

      it { is_expected.to fail_a_policy(:valid_credential_type) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates an encrypted credential" do
        expect { result }.to change { DiscourseWorkflows::Credential.count }.by(1)
        credential = DiscourseWorkflows::Credential.last
        expect(credential.name).to eq("My webhook auth")
        expect(credential.credential_type).to eq("basic_auth")
        expect(credential.decrypted_data).to eq("user" => "admin", "password" => "secret123")
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_credential_created",
          subject: "My webhook auth",
        )
      end
    end
  end
end
