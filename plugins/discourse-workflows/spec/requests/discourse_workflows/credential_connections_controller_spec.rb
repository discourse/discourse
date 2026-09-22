# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::CredentialConnectionsController do
  fab!(:admin)
  fab!(:credential, :discourse_workflows_oauth2_credential)

  let(:path) { "/admin/plugins/discourse-workflows/credentials/#{credential.id}/connect.json" }

  describe "#create" do
    before { sign_in(admin) }

    it "tests the connection and returns public connection details" do
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 200,
        body: { access_token: "private-token", token_type: "Bearer" }.to_json,
      )

      post path

      expect(response).to have_http_status(:ok)
      connection = response.parsed_body.fetch("credential").fetch("oauth_connection")
      expect(connection).to include("status" => "connected")
      expect(connection["details"]).to include(include("value" => "https://api.example.com"))
      expect(response.body).not_to include("private-token", credential.oauth_client_secret)
    end

    it "rejects static credentials and unauthorized users" do
      static_credential = Fabricate(:discourse_workflows_credential)
      post "/admin/plugins/discourse-workflows/credentials/#{static_credential.id}/connect.json"
      expect(response).to have_http_status(:unprocessable_entity)

      sign_in(Fabricate(:user))
      post path
      expect(response).to have_http_status(:not_found)
    end

    it "reports authentication failure without returning provider details" do
      private_error = "private provider diagnostics"
      stub_request(:post, "https://auth.example.com/token").to_return(
        status: 400,
        body: { error: "invalid_client", error_description: private_error }.to_json,
      )

      post path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.body).not_to include(private_error)
      expect(credential.reload.oauth_connection).to be_empty
    end

    context "with CSRF protection" do
      before { ActionController::Base.allow_forgery_protection = true }
      after { ActionController::Base.allow_forgery_protection = false }

      it "rejects a request without a token" do
        post path

        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
