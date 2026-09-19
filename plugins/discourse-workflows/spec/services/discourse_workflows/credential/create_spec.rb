# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Create do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(128) }
    it { is_expected.to validate_presence_of(:credential_type) }
    it { is_expected.to validate_length_of(:credential_type).is_at_most(64) }
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

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when contract is invalid" do
      let(:params) { { name: nil, credential_type: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when credential_type is not registered" do
      let(:params) { super().merge(credential_type: "unknown_type") }

      it { is_expected.to fail_a_policy(:valid_credential_type) }
    end

    context "when data is not a hash" do
      ["not-a-hash", %w[foo bar]].each do |non_hash|
        context "with #{non_hash.class}" do
          let(:params) { super().merge(data: non_hash) }

          it { is_expected.to fail_a_contract }
        end
      end
    end

    context "when data is missing a required field" do
      let(:params) { super().merge(data: { user: "admin" }) }

      it { is_expected.to fail_with_an_invalid_model(:credential) }
    end

    context "when a required field is empty" do
      let(:params) { super().merge(data: { user: "admin", password: "" }) }

      it { is_expected.to fail_with_an_invalid_model(:credential) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "creates a credential" do
        expect { result }.to change { DiscourseWorkflows::Credential.count }.by(1)
        credential = DiscourseWorkflows::Credential.last
        expect(credential.name).to eq("My webhook auth")
        expect(credential.credential_type).to eq("basic_auth")
        expect(credential.data).to eq("user" => "admin", "password" => "secret123")
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
