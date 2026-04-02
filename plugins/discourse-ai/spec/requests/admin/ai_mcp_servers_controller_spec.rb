# frozen_string_literal: true

RSpec.describe DiscourseAi::Admin::AiMcpServersController do
  fab!(:admin)
  fab!(:ai_secret)

  before do
    enable_current_plugin
    sign_in(admin)
    DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns([])
  end

  describe "GET #index" do
    fab!(:ai_mcp_server)

    it "returns mcp servers and secrets metadata" do
      DiscourseAi::Mcp::ToolRegistry.stubs(:tool_definitions_for).returns(
        [
          {
            "name" => "search_issues",
            "title" => "Search issues",
            "description" => "Search issues",
            "inputSchema" => {
              "type" => "object",
              "properties" => {
                "query" => {
                  "type" => "string",
                  "description" => "Search query",
                },
              },
              "required" => ["query"],
            },
          },
        ],
      )

      get "/admin/plugins/discourse-ai/ai-mcp-servers.json"

      expect(response).to be_successful
      expect(response.parsed_body["ai_mcp_servers"].length).to eq(1)
      expect(response.parsed_body["meta"]["ai_secrets"].length).to eq(1)
      expect(response.parsed_body["ai_mcp_servers"].first["tool_count"]).to eq(1)
      expect(response.parsed_body["ai_mcp_servers"].first["tools"]).to match(
        [
          a_hash_including(
            "name" => "search_issues",
            "title" => "Search issues",
            "description" => "Search issues",
            "parameters" => [
              {
                "name" => "query",
                "type" => "string",
                "description" => "Search query",
                "required" => true,
              },
            ],
            "token_count" => an_instance_of(Integer),
          ),
        ],
      )
    end
  end

  describe "browser routes under ai-tools" do
    fab!(:ai_mcp_server)

    it "serves the nested new path used by the Ember route" do
      get "/admin/plugins/discourse-ai/ai-tools/mcp-servers/new"

      expect(response).to be_successful
    end

    it "serves the nested edit path used by the Ember route" do
      get "/admin/plugins/discourse-ai/ai-tools/mcp-servers/#{ai_mcp_server.id}/edit"

      expect(response).to be_successful
    end
  end

  describe "POST #create" do
    it "creates an mcp server" do
      expect {
        post "/admin/plugins/discourse-ai/ai-mcp-servers.json",
             params: {
               ai_mcp_server: {
                 name: "Jira",
                 description: "Jira MCP",
                 url: "https://jira.example.com/mcp",
                 ai_secret_id: ai_secret.id,
               },
             }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.to change(AiMcpServer, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["ai_mcp_server"]["name"]).to eq("Jira")
    end

    it "persists advanced OAuth options" do
      post "/admin/plugins/discourse-ai/ai-mcp-servers.json",
           params: {
             ai_mcp_server: {
               name: "BigQuery",
               description: "BigQuery MCP",
               url: "https://bigquery.googleapis.com/mcp",
               auth_type: "oauth",
               oauth_client_registration: "manual",
               oauth_client_id: "client-id",
               oauth_client_secret_ai_secret_id: ai_secret.id,
               oauth_scopes: "https://www.googleapis.com/auth/bigquery",
               oauth_authorization_params: {
                 access_type: "offline",
               },
               oauth_token_params: {
                 audience: "https://bigquery.googleapis.com/",
               },
               oauth_require_refresh_token: true,
             },
           }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("ai_mcp_server", "oauth_authorization_params")).to eq(
        "access_type" => "offline",
      )
      expect(response.parsed_body.dig("ai_mcp_server", "oauth_token_params")).to eq(
        "audience" => "https://bigquery.googleapis.com/",
      )
      expect(response.parsed_body.dig("ai_mcp_server", "oauth_require_refresh_token")).to eq(true)
    end

    it "rejects localhost urls" do
      expect {
        post "/admin/plugins/discourse-ai/ai-mcp-servers.json",
             params: {
               ai_mcp_server: {
                 name: "Internal",
                 description: "Internal MCP",
                 url: "https://localhost/mcp",
               },
             }.to_json,
             headers: {
               "CONTENT_TYPE" => "application/json",
             }
      }.not_to change(AiMcpServer, :count)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(response.parsed_body["errors"].join(" ")).to include(
        I18n.t("discourse_ai.mcp_servers.invalid_url_not_reachable"),
      )
    end
  end

  describe "POST #test" do
    it "returns discovered tool metadata" do
      DiscourseAi::Mcp::Client
        .any_instance
        .stubs(:initialize_session)
        .returns(
          {
            session_id: "session-1",
            result: {
              "protocolVersion" => "2025-03-26",
              "capabilities" => {
                "tools" => {
                },
              },
            },
          },
        )
      DiscourseAi::Mcp::Client
        .any_instance
        .stubs(:list_tools)
        .returns([{ "name" => "search_issues" }, { "name" => "create_issue" }])

      post "/admin/plugins/discourse-ai/ai-mcp-servers/test.json",
           params: {
             ai_mcp_server: {
               name: "Jira",
               description: "Jira MCP",
               url: "https://jira.example.com/mcp",
             },
           }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to be_successful
      expect(response.parsed_body["tool_count"]).to eq(2)
      expect(response.parsed_body["tool_names"]).to contain_exactly("search_issues", "create_issue")
    end

    it "requires OAuth servers to be saved before testing" do
      post "/admin/plugins/discourse-ai/ai-mcp-servers/test.json",
           params: {
             ai_mcp_server: {
               name: "OAuth Docs",
               description: "OAuth server",
               url: "https://docs.example.com/mcp",
               auth_type: "oauth",
             },
           }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"]).to include(
        I18n.t("discourse_ai.mcp_servers.errors.oauth_save_before_connect"),
      )
    end

    it "does not reuse stored OAuth tokens when the OAuth configuration changes" do
      ai_mcp_server =
        Fabricate(:ai_mcp_server, auth_type: "oauth", url: "https://docs.example.com/mcp")
      ai_mcp_server.update_columns(
        oauth_status: "connected",
        oauth_access_token_expires_at: 10.minutes.from_now,
      )
      ai_mcp_server.oauth_token_store.write!(
        access_token: "stale-access-token",
        refresh_token: "refresh-token",
      )

      client = mock
      DiscourseAi::Mcp::Client
        .expects(:new)
        .with do |test_server|
          expect(test_server).not_to be_persisted
          expect(test_server.url).to eq("https://changed.example.com/mcp")
          expect(test_server.oauth_token_store.access_token).to be_blank
          expect(test_server.oauth_access_token_expires_at).to be_nil
          true
        end
        .returns(client)
      client.expects(:initialize_session).returns(
        {
          session_id: "session-1",
          result: {
            "protocolVersion" => "2025-03-26",
            "capabilities" => {
            },
          },
        },
      )
      client.expects(:list_tools).with(session_id: "session-1").returns([])

      post "/admin/plugins/discourse-ai/ai-mcp-servers/#{ai_mcp_server.id}/test.json",
           params: {
             ai_mcp_server: {
               name: ai_mcp_server.name,
               description: ai_mcp_server.description,
               url: "https://changed.example.com/mcp",
               auth_type: "oauth",
               oauth_client_registration: ai_mcp_server.oauth_client_registration,
             },
           }.to_json,
           headers: {
             "CONTENT_TYPE" => "application/json",
           }

      expect(response).to be_successful
    end
  end

  describe "GET #oauth_start" do
    fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

    it "redirects to the OAuth authorization URL" do
      DiscourseAi::Mcp::OAuthFlow
        .expects(:start!)
        .with(server: ai_mcp_server, user: admin)
        .returns("https://auth.example.com/authorize")

      get "/admin/plugins/discourse-ai/ai-mcp-servers/#{ai_mcp_server.id}/oauth/start.json"

      expect(response).to redirect_to("https://auth.example.com/authorize")
    end

    it "redirects to the OAuth authorization URL for the browser HTML route" do
      DiscourseAi::Mcp::OAuthFlow
        .expects(:start!)
        .with(server: ai_mcp_server, user: admin)
        .returns("https://auth.example.com/authorize")

      get "/admin/plugins/discourse-ai/ai-mcp-servers/#{ai_mcp_server.id}/oauth/start"

      expect(response).to redirect_to("https://auth.example.com/authorize")
    end
  end

  describe "GET #oauth_callback" do
    fab!(:ai_mcp_server) { Fabricate(:ai_mcp_server, auth_type: "oauth") }

    it "redirects back to the MCP server editor after authorization" do
      DiscourseAi::Mcp::OAuthFlow.expects(:complete!).returns(ai_mcp_server)

      get "/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback.json", params: { state: "abc" }

      expect(response).to redirect_to(ai_mcp_server.admin_edit_url)
    end

    it "redirects back to the MCP server editor for the browser HTML callback route" do
      DiscourseAi::Mcp::OAuthFlow.expects(:complete!).returns(ai_mcp_server)

      get "/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback", params: { state: "abc" }

      expect(response).to redirect_to(ai_mcp_server.admin_edit_url)
    end

    it "redirects to the server edit page on failure so the admin can see the error" do
      DiscourseAi::Mcp::OAuthFlow.expects(:complete!).raises(
        DiscourseAi::Mcp::OAuthFlow::OAuthError.new("Client not found", server: ai_mcp_server),
      )

      get "/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback", params: { state: "abc" }

      expect(response).to redirect_to(ai_mcp_server.admin_edit_url)
    end

    it "falls back to the tools page with a flash error when the server is unknown" do
      DiscourseAi::Mcp::OAuthFlow.expects(:complete!).raises(
        DiscourseAi::Mcp::OAuthFlow::OAuthError.new("invalid state"),
      )

      get "/admin/plugins/discourse-ai/ai-mcp-servers/oauth/callback", params: { state: "bad" }

      expect(response).to redirect_to("/admin/plugins/discourse-ai/ai-tools")
      expect(flash[:error]).to eq(
        I18n.t("discourse_ai.mcp_servers.errors.oauth_callback_failed", message: "invalid state"),
      )
    end
  end

  describe "DELETE #oauth_disconnect" do
    fab!(:ai_mcp_server) do
      Fabricate(:ai_mcp_server, auth_type: "oauth", oauth_status: "connected")
    end

    it "disconnects OAuth credentials and returns the updated server" do
      DiscourseAi::Mcp::OAuthFlow
        .expects(:disconnect!)
        .with(ai_mcp_server)
        .once { ai_mcp_server.clear_oauth_credentials! }

      delete "/admin/plugins/discourse-ai/ai-mcp-servers/#{ai_mcp_server.id}/oauth/disconnect.json"

      expect(response).to be_successful
      expect(response.parsed_body["ai_mcp_server"]["oauth_status"]).to eq("disconnected")
    end
  end
end
