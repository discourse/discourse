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
      fab!(:credential_1) { Fabricate(:discourse_workflows_credential, name: "First") }
      fab!(:credential_2) { Fabricate(:discourse_workflows_credential, name: "Second") }

      it { is_expected.to run_successfully }

      it "returns credentials ordered by id desc" do
        expect(result[:credentials].map(&:name)).to eq(%w[Second First])
      end

      it "returns total_rows" do
        expect(result[:total_rows]).to eq(2)
      end

      it "does not set load_more_url" do
        expect(result[:load_more_url]).to be_nil
      end
    end

    context "when paginating" do
      fab!(:credential_1) { Fabricate(:discourse_workflows_credential, name: "First") }
      fab!(:credential_2) { Fabricate(:discourse_workflows_credential, name: "Second") }
      fab!(:credential_3) { Fabricate(:discourse_workflows_credential, name: "Third") }

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
      fab!(:basic_credential) do
        Fabricate(:discourse_workflows_credential, credential_type: "basic_auth")
      end
      fab!(:other_credential) do
        Fabricate(:discourse_workflows_credential, credential_type: "api_key", name: "API Key")
      end

      let(:params) { { type: "basic_auth" } }

      it "returns only matching credentials" do
        expect(result[:credentials].map(&:id)).to eq([basic_credential.id])
      end

      it "returns total_rows scoped to type" do
        expect(result[:total_rows]).to eq(1)
      end

      context "with pagination" do
        fab!(:basic_credential_2) do
          Fabricate(:discourse_workflows_credential, credential_type: "basic_auth", name: "Auth 2")
        end

        let(:params) { { type: "basic_auth", limit: 1 } }

        it "includes type in load_more_url" do
          expect(result[:load_more_url]).to include("type=basic_auth")
        end
      end
    end
  end
end
