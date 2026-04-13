# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Webhook::Action::AuthenticateNode do
  fab!(:credential) do
    Fabricate(
      :discourse_workflows_credential,
      credential_type: "basic_auth",
      data:
        DiscourseWorkflows::CredentialEncryptor.encrypt(
          { "user" => "admin", "password" => "secret" },
        ),
    )
  end

  subject(:result) { described_class.call(node:, params:) }

  let(:node) do
    {
      "id" => "webhook-1",
      "type" => "trigger:webhook",
      "configuration" => {
        "authentication" => auth_mode,
        "credential_id" => credential.id,
      },
    }
  end

  let(:auth_mode) { "none" }
  let(:raw_authorization) { nil }
  let(:params) { OpenStruct.new(raw_authorization:) }

  describe ".call" do
    context "when authentication is none" do
      it "returns true" do
        expect(result).to be(true)
      end
    end

    context "when no configuration is present" do
      let(:node) { { "id" => "webhook-1", "type" => "trigger:webhook" } }

      it "returns true" do
        expect(result).to be(true)
      end
    end

    context "when authentication mode is unsupported" do
      let(:auth_mode) { "bearer_token" }

      it "logs a warning and returns false" do
        Rails.logger.expects(:warn).with(regexp_matches(/Unsupported webhook auth mode/))
        expect(result).to be(false)
      end
    end

    context "when authentication is basic_auth" do
      let(:auth_mode) { "basic_auth" }

      context "when credential is not found" do
        before { credential.destroy! }

        it "logs a warning and returns false" do
          Rails.logger.expects(:warn).with(regexp_matches(/credential not found/i))
          expect(result).to be(false)
        end
      end

      context "when credential decryption fails" do
        before { credential.update_column(:data, "invalid-encrypted-data") }

        it "logs a warning and returns false" do
          Rails.logger.expects(:warn).with(regexp_matches(/credential decryption failed/i))
          expect(result).to be(false)
        end
      end

      context "when no authorization header is present" do
        it "returns false" do
          expect(result).to be(false)
        end
      end

      context "when authorization header does not start with Basic" do
        let(:raw_authorization) { "Bearer some-token" }

        it "returns false" do
          expect(result).to be(false)
        end
      end

      context "when credentials are wrong" do
        let(:raw_authorization) { "Basic #{Base64.strict_encode64("wrong:creds")}" }

        it "returns false" do
          expect(result).to be(false)
        end
      end

      context "when credentials are correct" do
        let(:raw_authorization) { "Basic #{Base64.strict_encode64("admin:secret")}" }

        it "returns true" do
          expect(result).to be(true)
        end
      end
    end
  end
end
