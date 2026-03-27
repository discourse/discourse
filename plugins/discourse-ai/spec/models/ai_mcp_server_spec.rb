# frozen_string_literal: true

RSpec.describe AiMcpServer do
  fab!(:ai_secret)
  fab!(:oauth_client_secret, :ai_secret)

  before { enable_current_plugin }

  it "is valid with a public https url" do
    server = Fabricate.build(:ai_mcp_server, ai_secret: ai_secret)

    expect(server).to be_valid
  end

  it "rejects non-https urls" do
    server = Fabricate.build(:ai_mcp_server, url: "http://example.com")

    expect(server).not_to be_valid
    expect(server.errors[:url]).to include(I18n.t("discourse_ai.mcp_servers.invalid_url_not_https"))
  end

  it "rejects localhost urls" do
    server = Fabricate.build(:ai_mcp_server, url: "https://localhost/mcp")

    expect(server).not_to be_valid
    expect(server.errors[:url]).to include(
      I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable"),
    )
  end

  it "rejects private ip urls" do
    server = Fabricate.build(:ai_mcp_server, url: "https://127.0.0.1/mcp")

    expect(server).not_to be_valid
    expect(server.errors[:url]).to include(
      I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable"),
    )
  end

  it "builds a bearer auth header from the configured secret" do
    server = Fabricate(:ai_mcp_server, ai_secret: ai_secret, auth_scheme: "Bearer")

    expect(server.auth_header_value).to eq("Bearer #{ai_secret.secret}")
  end

  it "sends the raw secret when auth scheme is blank" do
    server = Fabricate(:ai_mcp_server, ai_secret: ai_secret, auth_scheme: "")

    expect(server.auth_header_value).to eq(ai_secret.secret)
  end

  it "requires an OAuth client ID for manual OAuth registration" do
    server =
      Fabricate.build(
        :ai_mcp_server,
        auth_type: "oauth",
        oauth_client_registration: "manual",
        oauth_client_secret_ai_secret_id: oauth_client_secret.id,
        oauth_client_id: nil,
      )

    expect(server).not_to be_valid
    expect(server.errors[:oauth_client_id]).to include(
      I18n.t("discourse_ai.mcp_servers.oauth_client_id_required"),
    )
  end

  it "builds an OAuth bearer header from the stored access token" do
    server =
      Fabricate(
        :ai_mcp_server,
        auth_type: "oauth",
        oauth_status: "connected",
        oauth_token_type: "Bearer",
      )
    server.oauth_token_store.write!(access_token: "oauth-access-token", refresh_token: "refresh")

    expect(server.auth_header_value).to eq("Bearer oauth-access-token")
    expect(server.oauth_token.access_token).to eq("oauth-access-token")
    expect(server.oauth_token.refresh_token).to eq("refresh")
  end

  it "capitalizes a lowercase OAuth token type in the Authorization header" do
    server =
      Fabricate(
        :ai_mcp_server,
        auth_type: "oauth",
        oauth_status: "connected",
        oauth_token_type: "bearer",
      )
    server.oauth_token_store.write!(access_token: "oauth-access-token", refresh_token: "refresh")

    expect(server.auth_header_value).to eq("Bearer oauth-access-token")
  end

  it "uses the client metadata URL unless manual registration is selected" do
    server = Fabricate(:ai_mcp_server, auth_type: "oauth")

    expect(server.effective_oauth_client_id).to eq(server.oauth_client_metadata_url)

    server.oauth_client_registration = "manual"
    server.oauth_client_id = "manual-client-id"

    expect(server.effective_oauth_client_id).to eq("manual-client-id")
  end

  it "prefers a dynamically registered client_id over the metadata URL" do
    server = Fabricate(:ai_mcp_server, auth_type: "oauth")
    server.store_dynamic_registration!(client_id: "dynamic-client-id")

    expect(server.reload.effective_oauth_client_id).to eq("dynamic-client-id")
  end

  it "clears dynamically registered client_id when OAuth credentials are cleared" do
    server = Fabricate(:ai_mcp_server, auth_type: "oauth")
    server.store_dynamic_registration!(client_id: "dynamic-client-id")

    server.clear_oauth_credentials!

    expect(server.reload.oauth_client_id).to be_nil
    expect(server.effective_oauth_client_id).to eq(server.oauth_client_metadata_url)
  end

  it "preserves dynamically registered client_id across normal saves" do
    server = Fabricate(:ai_mcp_server, auth_type: "oauth")
    server.store_dynamic_registration!(client_id: "dynamic-client-id")

    server.reload
    server.update!(description: "Updated description")

    expect(server.reload.oauth_client_id).to eq("dynamic-client-id")
  end

  it "clears stored OAuth credentials when the OAuth configuration changes" do
    server =
      Fabricate(
        :ai_mcp_server,
        auth_type: "oauth",
        oauth_status: "connected",
        oauth_token_type: "Bearer",
      )
    server.oauth_token_store.write!(access_token: "access-token", refresh_token: "refresh-token")

    server.update!(url: "https://different.example.com/mcp")

    expect(server.reload.oauth_status).to eq("disconnected")
    expect(server.oauth_token).to be_blank
    expect(server.oauth_token_store.access_token).to be_blank
    expect(server.oauth_token_store.refresh_token).to be_blank
  end

  it "memoizes serialized tools for count calculations" do
    server = Fabricate(:ai_mcp_server)

    server
      .expects(:tool_definitions)
      .once
      .returns(
        [{ "name" => "search_issues", "description" => "Search issues", "inputSchema" => {} }],
      )
    DiscourseAi::Agents::Tools::Mcp
      .expects(:class_instance)
      .once
      .returns(
        stub(
          signature: {
            description: "Search issues",
            json_schema: {
              type: "object",
              properties: {
                query: {
                  type: "string",
                  description: "Search query",
                },
              },
              required: ["query"],
            },
          },
        ),
      )

    expect(server.tools_for_serialization).to contain_exactly(
      a_hash_including(
        name: "search_issues",
        parameters: [
          a_hash_including(
            name: "query",
            type: "string",
            description: "Search query",
            required: true,
          ),
        ],
      ),
    )
    expect(server.tool_count).to eq(1)
    expect(server.token_count).to be > 0
  end
end
