# frozen_string_literal: true

describe "Data Explorer MCP tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:other_group, :group)
  fab!(:query) { Fabricate(:query, sql: "SELECT 1::integer AS value") }

  before do
    SiteSetting.data_explorer_enabled = true
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    Fabricate(:query_group, query:, group:)
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: "discourse_run_query") do |primitive|
      primitive.enabled = true
    end
  end

  def authorize(*extra_scopes, actor: user)
    group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Data Explorer test client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: actor,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization:)
  end

  def call_run_query(arguments = {})
    call_tool("discourse_run_query", { id: query.id }.merge(arguments))
  end

  def call_tool(name, arguments = {})
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name:,
             arguments:,
           },
         }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{@token}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
  end

  describe "query management" do
    fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
    fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }

    def operations
      {
        "discourse_create_query" => {
          name: "Query 猫",
          sql: "SELECT 2 AS value",
          confirm_save: true,
        },
        "discourse_update_query" => {
          id: query.id,
          name: "Updated 猫",
          confirm_save: true,
        },
        "discourse_delete_query" => {
          id: query.id,
          confirm_delete: true,
        },
      }
    end

    before do
      operations.each_key do |identifier|
        McpPrimitive.create!(kind: "tool", identifier:, enabled: true)
      end
    end

    it "registers admin mutations under a separate write scope" do
      operations.each_key do |name|
        tool = DiscourseMcp.registry.find(:tool, name)
        expect(tool).not_to be_nil
        expect(tool.required_scopes).to eq(["mcp:data-explorer:write"])
        expect(tool.annotations["readOnlyHint"]).to eq(false)
        expect(tool.risk).to eq(:administration)
      end
    end

    it "requires authentication" do
      operations.each do |name, arguments|
        call_tool(name, arguments)
        expect(response.status).to eq(401), name
      end
    end

    it "does not permit mutations with only the read scope" do
      authorize("mcp:data-explorer:read", actor: admin)

      operations.each do |name, arguments|
        call_tool(name, arguments)
        expect(response.status).to eq(403), name
        expect(response.headers["WWW-Authenticate"]).to include('scope="mcp:data-explorer:write"')
      end
      expect(query.reload.name).not_to eq("Updated 猫")
      expect(query.hidden).to eq(false)
    end

    it "denies moderators and regular users even with the write scope" do
      [moderator, user].each do |actor|
        authorize("mcp:data-explorer:write", actor:)
        operations.each do |name, arguments|
          call_tool(name, arguments)
          expect(response.status).to eq(403), name
        end
      end
      expect(query.reload.hidden).to eq(false)
    end

    it "keeps mutations unavailable when Data Explorer is disabled" do
      authorize("mcp:data-explorer:write", actor: admin)
      SiteSetting.data_explorer_enabled = false

      operations.each do |name, arguments|
        call_tool(name, arguments)
        expect(response.parsed_body).to have_key("error"), name
      end
      expect(query.reload.hidden).to eq(false)
    end

    it "creates an attributed query and group access without running SQL" do
      authorize("mcp:data-explorer:write", actor: admin)
      allow(DiscourseDataExplorer::QueryRunner).to receive(:run)

      call_tool(
        "discourse_create_query",
        operations.fetch("discourse_create_query").merge(
          description: "Description 猫",
          group_ids: [other_group.id],
        ),
      )

      expect(response.status).to eq(200)
      result = response.parsed_body.dig("result", "structuredContent")
      expect(result).to include("name" => "Query 猫", "group_ids" => [other_group.id])
      created = DiscourseDataExplorer::Query.find(result.fetch("id"))
      expect(created).to have_attributes(
        name: "Query 猫",
        sql: "SELECT 2 AS value",
        description: "Description 猫",
        user_id: admin.id,
      )
      expect(DiscourseDataExplorer::QueryRunner).not_to have_received(:run)
      audit =
        UserHistory.find_by!(acting_user_id: admin.id, custom_type: "data_explorer_query_created")
      expect(audit.details).to include(
        "query_id: #{created.id}",
        "group_ids: [#{other_group.id}]",
        "oauth_client_id:",
        "fields:",
      )
      expect(audit.details).not_to include(created.sql)
    end

    it "updates only supplied fields, clears group access, and invalidates changed SQL results" do
      authorize("mcp:data-explorer:write", actor: admin)
      original_user_id = query.user_id
      original_sql = query.sql
      allow(DiscourseDataExplorer::QueryRunner).to receive(:invalidate).and_call_original

      call_tool("discourse_update_query", operations.fetch("discourse_update_query"))

      expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
      expect(query.reload).to have_attributes(
        name: "Updated 猫",
        sql: original_sql,
        user_id: original_user_id,
      )
      expect(query.group_ids).to eq([group.id])
      expect(DiscourseDataExplorer::QueryRunner).not_to have_received(:invalidate)

      call_tool(
        "discourse_update_query",
        { id: query.id, sql: "SELECT 3 AS value", group_ids: [], confirm_save: true },
      )

      expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
      expect(query.reload.sql).to eq("SELECT 3 AS value")
      expect(query.group_ids).to eq([])
      expect(DiscourseDataExplorer::QueryRunner).to have_received(:invalidate).with(query.id)
      audit =
        UserHistory
          .where(acting_user_id: admin.id, custom_type: "data_explorer_query_updated")
          .order(:id)
          .last
      expect(audit.details).to include("query_id: #{query.id}", "group_ids: []", "sql")
      expect(audit.details).not_to include(query.sql)
    end

    it "hides a deleted query and removes its dashboard report" do
      authorize("mcp:data-explorer:write", actor: admin)
      ::AdminDashboard::Reports::Mounter.mount(
        source: DiscourseDataExplorer::AdminDashboardReportProvider::SOURCE_NAME,
        identifier: query.id.to_s,
        guardian: Guardian.new(admin),
      )

      call_tool("discourse_delete_query", operations.fetch("discourse_delete_query"))

      expect(response.parsed_body.dig("result", "structuredContent")).to include(
        "id" => query.id,
        "deleted" => true,
      )
      expect(query.reload.hidden).to eq(true)
      audit =
        UserHistory.find_by!(acting_user_id: admin.id, custom_type: "data_explorer_query_deleted")
      expect(audit.details).to include("query_id: #{query.id}")
      expect(
        AdminDashboardReport.where(
          source: DiscourseDataExplorer::AdminDashboardReportProvider::SOURCE_NAME,
          identifier: query.id.to_s,
        ),
      ).not_to exist
    end

    it "rejects unconfirmed, empty, oversized, and unknown inputs before writing" do
      authorize("mcp:data-explorer:write", actor: admin)
      original = query.attributes.slice("name", "sql", "description", "hidden", "user_id")
      invalid = [
        ["discourse_create_query", { name: "No confirmation", sql: "SELECT 1" }],
        ["discourse_create_query", { name: " ", sql: "SELECT 1", confirm_save: true }],
        ["discourse_create_query", { name: "a" * 256, sql: "SELECT 1", confirm_save: true }],
        ["discourse_create_query", { name: "Long SQL", sql: "a" * 100_001, confirm_save: true }],
        [
          "discourse_create_query",
          {
            name: "Long description",
            sql: "SELECT 1",
            description: "a" * 10_001,
            confirm_save: true,
          },
        ],
        ["discourse_update_query", { id: query.id, name: "Bad\0name", confirm_save: true }],
        ["discourse_update_query", { id: query.id, confirm_save: true }],
        [
          "discourse_update_query",
          operations.fetch("discourse_update_query").merge(user_id: user.id),
        ],
        ["discourse_delete_query", { id: query.id }],
        ["discourse_delete_query", { id: -1, confirm_delete: true }],
      ]
      invalid.each do |name, arguments|
        expect { call_tool(name, arguments) }.not_to change(DiscourseDataExplorer::Query, :count)
        body = response.parsed_body
        expect(body.key?("error") || body.dig("result", "isError")).to eq(true), arguments.inspect
        expect(response.status).to be < 500
      end
      call_tool(
        "discourse_create_query",
        operations.fetch("discourse_create_query").merge(group_ids: (0..100).to_a),
      )
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
      expect(query.reload.attributes.slice(*original.keys)).to eq(original)
      expect(query.group_ids).to eq([group.id])
    end

    it "does not partially save updates with unknown groups" do
      authorize("mcp:data-explorer:write", actor: admin)
      original_name = query.name
      call_tool(
        "discourse_update_query",
        operations.fetch("discourse_update_query").merge(group_ids: [Group.maximum(:id) + 1]),
      )

      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(query.reload.name).to eq(original_name)
      expect(query.group_ids).to eq([group.id])
    end

    it "does not restore a query hidden after the initial lookup" do
      authorize("mcp:data-explorer:write", actor: admin)
      original_name = query.name
      allow(DiscourseDataExplorer::McpTools::Support).to receive(
        :query!,
      ).and_wrap_original do |original, *args, **kwargs|
        loaded = original.call(*args, **kwargs)
        DiscourseDataExplorer::Query.where(id: loaded.id).update_all(hidden: true)
        loaded
      end

      call_tool("discourse_update_query", operations.fetch("discourse_update_query"))

      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(query.reload).to have_attributes(hidden: true, name: original_name)
    end

    it "does not update or delete hidden queries" do
      authorize("mcp:data-explorer:write", actor: admin)
      query.update!(hidden: true)
      %w[discourse_update_query discourse_delete_query].each do |name|
        call_tool(name, operations.fetch(name))
        expect(response.parsed_body.dig("result", "isError")).to eq(true)
      end
      expect(query.reload.hidden).to eq(true)
    end
  end

  it "requires the Data Explorer read scope before running a query" do
    authorize

    call_run_query

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:data-explorer:read"',
    )
  end

  it "runs an assigned query when the token has the Data Explorer read scope" do
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    call_run_query

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).to include(
      "columns" => ["value"],
      "rows" => [[1]],
    )
  end

  it "does not return explain output for an assigned query" do
    query.update!(sql: "SELECT id FROM users WHERE username = 'admin-only-query-predicate'")
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    call_run_query(explain: true)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).not_to have_key("explain")
    expect(response.body).not_to include("admin-only-query-predicate")
  end

  it "does not run a query when the token has scope but the user lacks query access" do
    query.query_groups.delete_all
    Fabricate(:query_group, query:, group: other_group)
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    call_run_query

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.parsed_body.dig("result", "content")).to eq(
      [{ "type" => "text", "text" => I18n.t("discourse_data_explorer.mcp.query_not_found") }],
    )
  end

  it "applies the Data Explorer API query rate limit" do
    SiteSetting.mcp_global_rate_limit_per_minute = 100
    global_setting :max_data_explorer_api_reqs_per_10_seconds, 1
    global_setting :max_data_explorer_api_req_mode, "block"
    RateLimiter.enable
    authorize(DiscourseDataExplorer::McpTools::READ_SCOPE)

    freeze_time
    call_run_query
    expect(response.status).to eq(200)

    call_run_query
    expect(response.status).to eq(429)
    expect(response.headers["Retry-After"]).to eq("10")
    expect(response.parsed_body).to eq(
      "jsonrpc" => "2.0",
      "id" => nil,
      "error" => {
        "code" => -32_000,
        "message" => "Rate limit exceeded",
      },
    )
  end
end
