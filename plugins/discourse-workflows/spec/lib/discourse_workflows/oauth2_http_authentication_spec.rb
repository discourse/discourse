# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::HttpRequest::V1 do
  fab!(:credential, :discourse_workflows_oauth2_credential)

  let(:url) { "https://api.example.com/contacts" }
  let(:configuration) do
    {
      "method" => "POST",
      "url" => url,
      "body_json" => '{"name":"Ada"}',
      "authentication" => "oauth2_client_credentials",
      "credentials" => {
        "auth" => {
          "id" => credential.id,
          "credential_type" => "oauth2_client_credentials",
        },
      },
    }
  end

  describe "#execute" do
    it "obtains a bearer token and redacts it from request logs" do
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: { access_token: "private-token", token_type: "Bearer" }.to_json,
        )
      api_request =
        stub_request(:post, url).with(
          headers: {
            "Authorization" => "Bearer private-token",
          },
          body: configuration["body_json"],
        ).to_return(
          status: 201,
          body: { id: "contact-id" }.to_json,
          headers: {
            "content-type" => "application/json",
          },
        )
      messages = nil

      output =
        execute_node_output(configuration: configuration, item: { "json" => {} }) do |context|
          messages = context.log.entries.map { |entry| entry["message"] }
        end

      expect(output.first.first["json"]).to eq("id" => "contact-id")
      expect(authentication).to have_been_requested.once
      expect(api_request).to have_been_requested.once
      expect(messages.join).not_to include("private-token", credential.oauth_client_secret)
    end

    it "rejects a static credential selected for an OAuth2 authentication mode" do
      static_credential = Fabricate(:discourse_workflows_credential)
      configuration["credentials"]["auth"] = { "id" => static_credential.id }

      expect { execute_node(configuration: configuration, item: { "json" => {} }) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "does not replay a write on a generic unauthorized response and reacquires a token on the next run" do
      authentication =
        stub_request(:post, "https://auth.example.com/token").to_return(
          status: 200,
          body: { access_token: "private-token", token_type: "Bearer" }.to_json,
        )
      api_request = stub_request(:post, url).to_return(status: 401, body: "private diagnostics")

      expect { execute_node(configuration: configuration, item: { "json" => {} }) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
      expect(api_request).to have_been_requested.once
      expect(authentication).to have_been_requested.once
      expect(credential.reload.oauth_connection["status"]).to eq("reconnect_required")

      expect { execute_node(configuration: configuration, item: { "json" => {} }) }.to raise_error(
        DiscourseWorkflows::NodeError,
      )
      expect(authentication).to have_been_requested.twice
      expect(api_request).to have_been_requested.twice
    end

    it "surfaces an unauthorized response as output when the node never errors" do
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 200,
        body: { access_token: "private-token", token_type: "Bearer" }.to_json,
      )
      stub_request(:post, url).to_return(
        status: 401,
        body: { error: "denied" }.to_json,
        headers: {
          "content-type" => "application/json",
        },
      )
      configuration.merge!("never_error" => true, "full_response" => true)

      result = execute_node(configuration: configuration, item: { "json" => {} })

      expect(result).to include("status_code" => 401)
      expect(credential.reload.oauth_connection["status"]).to eq("reconnect_required")
    end
  end
end
