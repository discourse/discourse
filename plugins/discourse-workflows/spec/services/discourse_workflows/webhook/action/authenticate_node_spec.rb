# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Action::AuthenticateNode do
  fab!(:basic_credential) do
    Fabricate(
      :discourse_workflows_credential,
      credential_type: "basic_auth",
      data: {
        "user" => "admin",
        "password" => "secret",
      },
    )
  end

  fab!(:bearer_credential) do
    Fabricate(
      :discourse_workflows_credential,
      credential_type: "bearer_token",
      data: {
        "token" => "secret-token",
      },
    )
  end

  fab!(:header_credential) do
    Fabricate(
      :discourse_workflows_credential,
      credential_type: "header_auth",
      data: {
        "name" => "X-Api-Key",
        "value" => "secret-value",
      },
    )
  end

  subject(:result) { described_class.call(node:, params:, credentials:) }

  let(:credentials) do
    {
      basic_credential.id => basic_credential,
      bearer_credential.id => bearer_credential,
      header_credential.id => header_credential,
    }
  end
  let(:credential_id) { basic_credential.id.to_s }
  let(:credential_type) { "basic_auth" }

  let(:node) do
    {
      "id" => "webhook-1",
      "type" => "trigger:webhook",
      "parameters" => {
        "authentication" => auth_mode,
      },
      "credentials" => {
        "auth" => {
          "id" => credential_id,
          "credential_type" => credential_type,
        },
      },
    }
  end

  let(:auth_mode) { "none" }
  let(:raw_authorization) { nil }
  let(:headers) { {} }
  let(:params) { OpenStruct.new(raw_authorization:, headers:) }

  describe ".call" do
    context "when authentication is none" do
      it "returns :authenticated" do
        expect(result).to eq(:authenticated)
      end
    end

    context "when no configuration is present" do
      let(:node) { { "id" => "webhook-1", "type" => "trigger:webhook" } }

      it "returns :authenticated" do
        expect(result).to eq(:authenticated)
      end
    end

    context "when authentication mode is unsupported" do
      let(:auth_mode) { "unsupported_mode" }

      it "logs a warning and returns :misconfigured" do
        Rails.logger.expects(:warn).with(regexp_matches(/Unsupported webhook auth mode/))
        expect(result).to eq(:misconfigured)
      end
    end

    context "when authentication is basic_auth" do
      let(:auth_mode) { "basic_auth" }

      context "when credential is not found" do
        let(:credentials) { {} }

        it "logs a warning and returns :misconfigured" do
          Rails.logger.expects(:warn).with(regexp_matches(/credential not found/i))
          expect(result).to eq(:misconfigured)
        end
      end

      context "when no authorization header is present" do
        it "returns :challenge" do
          expect(result).to eq(:challenge)
        end
      end

      context "when authorization header does not start with Basic" do
        let(:raw_authorization) { "Bearer some-token" }

        it "returns :challenge" do
          expect(result).to eq(:challenge)
        end
      end

      context "when credentials are wrong" do
        let(:raw_authorization) { "Basic #{Base64.strict_encode64("wrong:creds")}" }

        it "returns :denied" do
          expect(result).to eq(:denied)
        end
      end

      context "when credentials are correct" do
        let(:raw_authorization) { "Basic #{Base64.strict_encode64("admin:secret")}" }

        it "returns :authenticated" do
          expect(result).to eq(:authenticated)
        end
      end

      context "when credential data is missing required fields" do
        before { basic_credential.update_column(:data, { "user" => "admin" }) }

        it "returns :misconfigured" do
          expect(result).to eq(:misconfigured)
        end
      end
    end

    context "when authentication is bearer_auth" do
      let(:auth_mode) { "bearer_auth" }
      let(:credential_id) { bearer_credential.id.to_s }
      let(:credential_type) { "bearer_token" }

      context "when authorization header is missing" do
        it "returns :denied" do
          expect(result).to eq(:denied)
        end
      end

      context "when token is wrong" do
        let(:raw_authorization) { "Bearer wrong-token" }

        it "returns :denied" do
          expect(result).to eq(:denied)
        end
      end

      context "when token is correct" do
        let(:raw_authorization) { "Bearer secret-token" }

        it "returns :authenticated" do
          expect(result).to eq(:authenticated)
        end
      end

      context "when credential is missing the token field" do
        before { bearer_credential.update_column(:data, {}) }

        it "returns :misconfigured" do
          expect(result).to eq(:misconfigured)
        end
      end
    end

    context "when authentication is header_auth" do
      let(:auth_mode) { "header_auth" }
      let(:credential_id) { header_credential.id.to_s }
      let(:credential_type) { "header_auth" }

      context "when header is missing" do
        it "returns :denied" do
          expect(result).to eq(:denied)
        end
      end

      context "when header value is wrong" do
        let(:headers) { { "x-api-key" => "wrong" } }

        it "returns :denied" do
          expect(result).to eq(:denied)
        end
      end

      context "when header value matches" do
        let(:headers) { { "x-api-key" => "secret-value" } }

        it "returns :authenticated" do
          expect(result).to eq(:authenticated)
        end
      end

      context "when credential is missing name or value" do
        before { header_credential.update_column(:data, { "name" => "X-Api-Key" }) }

        it "returns :misconfigured" do
          expect(result).to eq(:misconfigured)
        end
      end
    end
  end
end
