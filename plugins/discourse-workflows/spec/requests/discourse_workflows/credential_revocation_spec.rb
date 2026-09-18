# frozen_string_literal: true

RSpec.describe "OAuth2 credential revocation", type: :request do
  fab!(:admin)
  fab!(:credential) do
    Fabricate(
      :discourse_workflows_oauth2_credential,
      data: {
        "token_url" => "https://auth.example.com/token",
        "revoke_url" => "https://auth.example.com/revoke",
        "api_origin" => "https://api.example.com",
        "client_id" => "workflow-client",
        "client_secret" => "workflow-secret",
      },
    )
  end

  let(:path) { "/admin/plugins/discourse-workflows/credentials/#{credential.id}.json" }
  let(:connection) do
    {
      "status" => "connected",
      "grant_type" => "client_credentials",
      "access_token" => "access-secret",
    }
  end

  before do
    SiteSetting.enable_discourse_workflows = true
    sign_in(admin)
    credential.oauth_connection = connection
    credential.save!
  end

  describe "PUT /credentials/:id" do
    it "keeps the cached token when only the name changes" do
      put path, params: { name: "Renamed" }

      expect(response).to have_http_status(:ok)
      expect(credential.reload.name).to eq("Renamed")
      expect(credential.oauth_connection).to eq(connection)
    end

    it "revokes and disconnects when app details change" do
      revocation =
        stub_request(:post, "https://auth.example.com/revoke").with(
          body: {
            token: "access-secret",
          },
        ).to_return(status: 200)

      put path, params: { name: credential.name, data: { client_secret: "new-secret" } }

      expect(response).to have_http_status(:ok)
      expect(revocation).to have_been_requested.once
      expect(credential.reload.oauth_connection).to be_empty
      expect(credential.oauth_client_secret).to eq("new-secret")
    end

    it "keeps the old configuration and connection if revocation fails" do
      original_data = credential.data
      stub_request(:post, "https://auth.example.com/revoke").to_return(status: 503)

      put path, params: { name: credential.name, data: { client_id: "different-client" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq(
        [I18n.t("discourse_workflows.oauth2.errors.revocation_failed")],
      )
      expect(credential.reload.data).to eq(original_data)
    end

    it "validates configuration before revoking the connection" do
      put path, params: { name: credential.name, data: { token_url: "http://auth.example.com" } }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(credential.reload.oauth_connection).to eq(connection)
      expect(credential.data["token_url"]).to eq("https://auth.example.com/token")
    end
  end

  describe "DELETE /credentials/:id" do
    it "revokes the access token before deleting the row" do
      revocation =
        stub_request(:post, "https://auth.example.com/revoke")
          .with(body: { token: "access-secret" })
          .to_return do
            expect(DiscourseWorkflows::Credential.exists?(credential.id)).to eq(true)
            { status: 200 }
          end

      delete path

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Credential.exists?(credential.id)).to eq(false)
      expect(revocation).to have_been_requested.once
    end

    it "keeps the row and tokens when the provider cannot be reached" do
      stub_request(:post, "https://auth.example.com/revoke").to_timeout

      delete path

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"]).to eq(
        [I18n.t("discourse_workflows.oauth2.errors.provider_unavailable")],
      )
      expect(credential.reload.oauth_connection).to eq(connection)
    end

    it "deletes an already revoked connection" do
      stub_request(:post, "https://auth.example.com/revoke").to_return(
        status: 400,
        body: { error: "invalid_token" }.to_json,
      )

      delete path

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Credential.exists?(credential.id)).to eq(false)
    end

    it "deletes without a revocation request when none is configured" do
      credential.update!(data: credential.data.except("revoke_url"))

      delete path

      expect(response).to have_http_status(:no_content)
      expect(DiscourseWorkflows::Credential.exists?(credential.id)).to eq(false)
    end
  end
end
