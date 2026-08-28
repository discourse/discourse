# frozen_string_literal: true

describe Admin::McpClientsController do
  fab!(:admin)

  before do
    sign_in(admin)
    SiteSetting.mcp_oauth_client_trust_policy = "approved_domains"
    SiteSetting.mcp_oauth_approved_domains = "client.example.com"
  end

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
