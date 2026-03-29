# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:credential, :discourse_workflows_credential) do
      Fabricate(:discourse_workflows_credential, name: "Old name")
    end

    let(:params) do
      {
        credential_id: credential.id,
        name: "New name",
        data: {
          user: "__REDACTED__",
          password: "new_password",
        },
      }
    end
    let(:dependencies) { { guardian: admin.guardian } }

    context "when contract is invalid" do
      let(:params) { { credential_id: credential.id, name: nil } }

      it { is_expected.to fail_a_contract }
    end

    context "when credential not found" do
      let(:params) { super().merge(credential_id: -1) }

      it { is_expected.to fail_to_find_a_model(:credential) }
    end

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the name" do
        result
        expect(credential.reload.name).to eq("New name")
      end

      it "preserves redacted values from original data" do
        result
        decrypted = credential.reload.decrypted_data
        expect(decrypted["user"]).to eq("admin")
        expect(decrypted["password"]).to eq("new_password")
      end

      it "logs a staff action" do
        expect { result }.to change { UserHistory.count }.by(1)
        expect(UserHistory.last).to have_attributes(
          custom_type: "discourse_workflows_credential_updated",
          subject: "New name",
        )
      end
    end

    context "when all values are redacted" do
      let(:params) do
        {
          credential_id: credential.id,
          name: "New name",
          data: {
            user: "__REDACTED__",
            password: "__REDACTED__",
          },
        }
      end

      it "preserves all original values" do
        result
        decrypted = credential.reload.decrypted_data
        expect(decrypted["user"]).to eq("admin")
        expect(decrypted["password"]).to eq("secret")
      end
    end
  end
end
