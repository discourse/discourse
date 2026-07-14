# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::Update do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of(:credential_id) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(128) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    fab!(:credential) { Fabricate(:discourse_workflows_credential, name: "Old name") }

    let(:params) do
      {
        credential_id: credential.id,
        name: "New name",
        data: {
          user: DiscourseWorkflows::Credential::REDACTED_VALUE,
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

    context "when name is too long" do
      let(:params) { super().merge(name: "x" * 200) }

      it { is_expected.to fail_a_contract }
    end

    context "when everything is valid" do
      it { is_expected.to run_successfully }

      it "updates the name" do
        result
        expect(credential.reload.name).to eq("New name")
      end

      it "preserves redacted values from original data" do
        result
        data = credential.reload.data
        expect(data["user"]).to eq("admin")
        expect(data["password"]).to eq("new_password")
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
            user: DiscourseWorkflows::Credential::REDACTED_VALUE,
            password: DiscourseWorkflows::Credential::REDACTED_VALUE,
          },
        }
      end

      it "preserves all original values" do
        result
        data = credential.reload.data
        expect(data["user"]).to eq("admin")
        expect(data["password"]).to eq("secret")
      end
    end

    context "when data is not provided" do
      let(:params) { { credential_id: credential.id, name: "New name" } }

      it { is_expected.to run_successfully }

      it "updates only the name" do
        result
        credential.reload
        expect(credential.name).to eq("New name")
        expect(credential.data).to eq({ "user" => "admin", "password" => "secret" })
      end
    end

    context "when data is a partial payload omitting original keys" do
      let(:params) do
        { credential_id: credential.id, name: "New name", data: { password: "new_password" } }
      end

      it "preserves keys that were not sent" do
        result
        expect(credential.reload.data).to eq("user" => "admin", "password" => "new_password")
      end
    end

    context "when data contains a new key not in the original" do
      let(:params) { { credential_id: credential.id, name: "New name", data: { extra: "value" } } }

      it "adds the new key while preserving originals" do
        result
        expect(credential.reload.data).to eq(
          "user" => "admin",
          "password" => "secret",
          "extra" => "value",
        )
      end
    end

    context "when data is not a hash" do
      ["not-a-hash", %w[foo bar]].each do |non_hash|
        context "with #{non_hash.class}" do
          let(:params) { super().merge(data: non_hash) }

          it { is_expected.to fail_a_contract }
        end
      end
    end

    context "when an explicit empty value would clear a required field" do
      let(:params) { { credential_id: credential.id, name: "New name", data: { password: "" } } }

      it { is_expected.to fail_with_an_invalid_model(:credential) }
    end
  end
end
