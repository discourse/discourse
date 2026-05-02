# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::Authenticator do
  describe ".apply" do
    it "does nothing when authentication is none" do
      headers = {}
      described_class.apply({ "authentication" => "none" }, headers, nil)

      expect(headers).not_to have_key("Authorization")
    end

    it "does nothing when authentication is not specified" do
      headers = {}
      described_class.apply({}, headers, nil)

      expect(headers).not_to have_key("Authorization")
    end

    it "raises when credential_id is missing for auth modes" do
      expect {
        described_class.apply({ "authentication" => "basic_auth" }, {}, nil)
      }.to raise_error(ArgumentError, /credential_id is required/)
    end

    context "with basic_auth" do
      it "sets Authorization header with Base64 credentials" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credential: {
              "user" => "api_user",
              "password" => "api_pass",
            },
          )

        described_class.apply(
          { "authentication" => "basic_auth", "credential_id" => 1 },
          headers,
          exec_ctx,
        )

        expected = "Basic #{Base64.strict_encode64("api_user:api_pass")}"
        expect(headers["Authorization"]).to eq(expected)
        expect(exec_ctx).to have_received(:get_credential).with(1)
      end
    end

    context "with bearer_token" do
      it "sets Bearer Authorization header" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credential: {
              "token" => "my-secret-token",
            },
          )

        described_class.apply(
          { "authentication" => "bearer_token", "credential_id" => 1 },
          headers,
          exec_ctx,
        )

        expect(headers["Authorization"]).to eq("Bearer my-secret-token")
        expect(exec_ctx).to have_received(:get_credential).with(1)
      end
    end
  end
end
