# frozen_string_literal: true

describe Admin::McpClientsController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.mcp_oauth_client_id_metadata_policy = "approved_domains"
    SiteSetting.mcp_oauth_client_id_metadata_domains = "client.example.com"
  end

  describe "#index" do
    it "paginates clients" do
      older_client = create_client(client_id: "older-client", name: "Older client")
      newer_client = create_client(client_id: "newer-client", name: "Newer client")

      get "/admin/mcp/clients.json", params: { limit: 1 }

      expect(response.status).to eq(200)
      expect(response.parsed_body["clients"].pluck("id")).to eq([newer_client.id])

      get "/admin/mcp/clients.json",
          params: {
            limit: 1,
            cursor: response.parsed_body.dig("meta", "next_cursor"),
          }

      expect(response.parsed_body["clients"].pluck("id")).to eq([older_client.id])
    end

    it "filters clients before applying the page limit" do
      older_client = create_client(client_id: "older-client", name: "Matching client")
      create_client(client_id: "newer-client", name: "Other client")

      get "/admin/mcp/clients.json", params: { limit: 1, filter: "matching" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["clients"].pluck("id")).to eq([older_client.id])
    end
  end

  describe "#create" do
    it "serializes a non-URL client ID that starts with HTTPS" do
      post "/admin/mcp/clients.json",
           params: {
             client: {
               client_id: "https://%",
               name: "Malformed URL-like ID",
               redirect_uris: ["https://client.example.com/callback"],
             },
           }

      expect(response.status).to eq(201)
      expect(response.parsed_body.dig("client", "client_id")).to eq("https://%")
      expect(response.parsed_body.dig("client", "domain")).to eq(nil)
    end
  end

  describe "#update" do
    let!(:client) { create_client(client_id: "example-client", name: "Example client") }
    let(:redirect_uri) { "https://client.example.com/corrected-callback" }

    it "corrects a registration without changing its identity or trust" do
      client.update!(trust_state: "blocked")

      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              name: "Updated client",
              redirect_uris: [redirect_uri],
              client_id: "replacement",
              trust_state: "approved",
              registration_type: "cimd",
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("client", "redirect_uris")).to eq([redirect_uri])
      expect(client.reload).to have_attributes(
        name: "Updated client",
        redirect_uris: [redirect_uri],
        client_id: "example-client",
        trust_state: "blocked",
        registration_type: "pre_registered",
      )
      expect(UserHistory.last).to have_attributes(
        acting_user_id: admin.id,
        custom_type: "mcp_client_updated",
      )
    end

    it "rejects invalid redirect URIs without saving other changes" do
      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              name: "Updated client",
              redirect_uris: ["https://"],
            },
          }

      expect(response.status).to eq(422)
      expect(client.reload.name).to eq("Example client")
    end

    it "saves both callbacks when adding a redirect URI" do
      redirect_uris = client.redirect_uris + [redirect_uri]

      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              redirect_uris: redirect_uris,
            },
          }

      expect(response.status).to eq(200)
      expect(client.reload.redirect_uris).to eq(redirect_uris)
    end

    it "switches a metadata client to admin management when editing redirect URIs" do
      client.update!(registration_type: "cimd")

      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              redirect_uris: [redirect_uri],
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("client", "admin_managed")).to eq(true)
      expect(client.reload).to have_attributes(
        redirect_uris: [redirect_uri],
        registration_type: "cimd",
        trust_state: "approved",
      )
    end

    it "switches a metadata client to admin management when editing its name" do
      client.update!(registration_type: "cimd")

      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              name: "Renamed client",
              redirect_uris: client.redirect_uris,
            },
          }

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("client", "admin_managed")).to eq(true)
      expect(client.reload.name).to eq("Renamed client")
    end

    it "rejects moderators" do
      sign_in(Fabricate(:moderator))

      put "/admin/mcp/clients/#{client.id}.json",
          params: {
            client: {
              redirect_uris: [redirect_uri],
            },
          }

      expect(response.status).to eq(404)
      expect(client.reload.redirect_uris).to eq(["https://client.example.com/callback"])
    end
  end

  describe "#refresh" do
    it "refreshes client ID metadata for an approved domain" do
      client_id = "https://client.example.com/oauth/client.json"
      client =
        McpOauthClient.create!(
          client_id:,
          name: "Old name",
          registration_type: "cimd",
          trust_state: "approved",
          metadata_uri: client_id,
          redirect_uris: ["https://client.example.com/callback"],
        )
      allow(DiscourseMcp::OAuth::ClientResolver).to receive(:fetch_metadata).and_return(
        {
          "client_id" => client_id,
          "client_name" => "Updated name",
          "redirect_uris" => ["https://client.example.com/callback"],
        },
      )

      post "/admin/mcp/clients/#{client.id}/refresh.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("client", "name")).to eq("Updated name")
      expect(client.reload.name).to eq("Updated name")
    end
  end

  def create_client(client_id:, name:)
    McpOauthClient.create!(
      client_id:,
      name:,
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["https://client.example.com/callback"],
    )
  end
end
