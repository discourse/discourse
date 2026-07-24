# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::Authenticator do
  describe ".apply" do
    it "does nothing when authentication is none" do
      headers = {}
      result = described_class.apply({ "authentication" => "none" }, headers, nil)

      expect(headers).not_to have_key("Authorization")
      expect(result).to eq([])
    end

    it "does nothing when authentication is not specified" do
      headers = {}
      result = described_class.apply({}, headers, nil)

      expect(headers).not_to have_key("Authorization")
      expect(result).to eq([])
    end

    it "raises when the auth credential slot is missing for auth modes" do
      exec_ctx =
        instance_double(DiscourseWorkflows::Executor::NodeExecutionContext, get_credentials: nil)
      allow(exec_ctx).to receive(:get_credentials).with("auth", 0).and_raise(
        Discourse::InvalidAccess,
      )

      expect {
        described_class.apply({ "authentication" => "basic_auth" }, {}, exec_ctx)
      }.to raise_error(Discourse::InvalidAccess)
    end

    context "with basic_auth" do
      it "sets Authorization header with Base64 credentials" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "user" => "api_user",
              "password" => "api_pass",
            },
          )

        result = described_class.apply({ "authentication" => "basic_auth" }, headers, exec_ctx)

        expected = "Basic #{Base64.strict_encode64("api_user:api_pass")}"
        expect(headers["Authorization"]).to eq(expected)
        expect(result).to eq(["Authorization"])
      end
    end

    context "with bearer_token" do
      it "sets Bearer Authorization header" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "token" => "my-secret-token",
            },
          )

        result = described_class.apply({ "authentication" => "bearer_token" }, headers, exec_ctx)

        expect(headers["Authorization"]).to eq("Bearer my-secret-token")
        expect(result).to eq(["Authorization"])
      end
    end

    context "with header_auth" do
      it "sets the custom header from the credential" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "name" => "X-API-Key",
              "value" => "my-secret-key",
            },
          )

        result = described_class.apply({ "authentication" => "header_auth" }, headers, exec_ctx)

        expect(headers["X-API-Key"]).to eq("my-secret-key")
        expect(result).to eq(["X-API-Key"])
      end

      it "raises when the resolved header name is blank" do
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "name" => "",
              "value" => "my-secret-key",
            },
          )

        expect {
          described_class.apply({ "authentication" => "header_auth" }, {}, exec_ctx)
        }.to raise_error(DiscourseWorkflows::NodeError, /Header name contains invalid characters/)
      end

      it "raises when the resolved header name injects CRLF" do
        headers = {}
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "name" => "X-Foo\r\nX-Injected: evil",
              "value" => "my-secret-key",
            },
          )

        expect {
          described_class.apply({ "authentication" => "header_auth" }, headers, exec_ctx)
        }.to raise_error(DiscourseWorkflows::NodeError, /Header name contains invalid characters/)
        expect(headers).to be_empty
      end

      it "raises when the resolved header name contains other illegal characters" do
        exec_ctx =
          instance_double(
            DiscourseWorkflows::Executor::NodeExecutionContext,
            get_credentials: {
              "name" => "X Api Key",
              "value" => "my-secret-key",
            },
          )

        expect {
          described_class.apply({ "authentication" => "header_auth" }, {}, exec_ctx)
        }.to raise_error(DiscourseWorkflows::NodeError, /Header name contains invalid characters/)
      end
    end
  end
end
