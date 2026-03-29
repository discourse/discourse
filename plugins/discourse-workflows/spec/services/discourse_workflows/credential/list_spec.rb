# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Credential::List do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { {} }
    let(:dependencies) { { guardian: admin.guardian } }

    context "when user cannot manage workflows" do
      fab!(:user)

      let(:dependencies) { { guardian: user.guardian } }

      it { is_expected.to fail_a_policy(:can_manage_workflows) }
    end

    context "when credentials exist" do
      fab!(:credential_1, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, name: "First")
      end
      fab!(:credential_2, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, name: "Second")
      end

      it { is_expected.to run_successfully }

      it "returns credentials ordered by id desc" do
        expect(result[:credentials].map(&:name)).to eq(%w[Second First])
      end

      it "returns total_rows" do
        expect(result[:total_rows]).to eq(2)
      end
    end

    context "when paginating" do
      fab!(:credential_1, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, name: "First")
      end
      fab!(:credential_2, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, name: "Second")
      end
      fab!(:credential_3, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, name: "Third")
      end

      let(:params) { { limit: 2 } }

      it "returns load_more_url when more results exist" do
        expect(result[:credentials].length).to eq(2)
        expect(result[:load_more_url]).to include("cursor=")
      end

      context "with cursor" do
        let(:params) { { cursor: credential_3.id, limit: 10 } }

        it "returns credentials before cursor" do
          expect(result[:credentials].map(&:name)).to eq(%w[Second First])
        end
      end
    end

    context "when filtering by type" do
      fab!(:basic_credential, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, credential_type: "basic_auth")
      end
      fab!(:other_credential, :discourse_workflows_credential) do
        Fabricate(:discourse_workflows_credential, credential_type: "api_key", name: "API Key")
      end

      let(:params) { { type: "basic_auth" } }

      it "returns only matching credentials" do
        expect(result[:credentials].map(&:id)).to eq([basic_credential.id])
      end
    end
  end
end
