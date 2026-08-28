# frozen_string_literal: true

describe Admin::McpActivityController do
  fab!(:admin)

  describe "#index" do
    before { sign_in(admin) }

    it "returns activity and calculates the 24-hour metrics in one query" do
      McpAuditLog.create!(
        occurred_at: Time.zone.now,
        method: "tools/call",
        tool: "discourse.search",
        outcome: "success",
        occurrences: 2,
        duration_ms: 10,
      )
      McpAuditLog.create!(
        occurred_at: Time.zone.now,
        method: "tools/call",
        tool: "discourse.topic.create",
        outcome: "error",
        occurrences: 3,
        duration_ms: 100,
      )
      McpAuditLog.create!(
        occurred_at: Time.zone.now,
        method: "tools/call",
        outcome: "rate_limited",
        occurrences: 4,
        duration_ms: 200,
      )

      queries = track_sql_queries { get "/admin/mcp/activity.json" }

      expect(response.status).to eq(200)
      expect(response.parsed_body["metrics"]).to eq(
        "tool_calls" => 9,
        "errors" => 7,
        "rate_limits" => 4,
        "p95_latency_ms" => 200,
      )
      expect(response.parsed_body.dig("activity", 2, "tool")).to eq("discourse.search")
      metric_queries =
        queries.select do |sql|
          sql.include?('FROM "mcp_audit_logs"') && sql.match?(/occurred_at.*>/)
        end
      expect(metric_queries.length).to eq(1)
    end

    it "filters users, clients, tools, outcomes, and exact request IDs on the server" do
      user = Fabricate(:user, username: "activity-needle-user")
      client =
        McpOauthClient.create!(
          client_id: "activity-needle-client",
          name: "Activity Needle Client",
          registration_type: "pre_registered",
          trust_state: "approved",
          redirect_uris: ["http://127.0.0.1/callback"],
        )
      matching_log =
        McpAuditLog.create!(
          occurred_at: Time.zone.now,
          user: user,
          client: client,
          method: "tools/call",
          tool: "discourse.activity.needle",
          outcome: "error",
          request_id: "activity-request-exact",
        )
      McpAuditLog.create!(
        occurred_at: Time.zone.now,
        method: "tools/call",
        tool: "discourse.other",
        outcome: "success",
        request_id: "other-request",
      )

      [user.username, client.name, client.client_id, matching_log.tool].each do |filter|
        get "/admin/mcp/activity.json", params: { filter: filter }

        expect(response.parsed_body["activity"].map { |entry| entry["id"] }).to eq(
          [matching_log.id],
        )
      end

      get "/admin/mcp/activity.json", params: { outcome: "error" }
      expect(response.parsed_body["activity"].map { |entry| entry["id"] }).to eq([matching_log.id])

      get "/admin/mcp/activity.json", params: { filter: matching_log.request_id }
      expect(response.parsed_body["activity"].map { |entry| entry["id"] }).to eq([matching_log.id])

      get "/admin/mcp/activity.json", params: { filter: "activity-request" }
      expect(response.parsed_body["activity"]).to be_empty
    end

    it "applies filters before pagination and omits metrics from cursor requests" do
      older_match =
        McpAuditLog.create!(
          occurred_at: 2.minutes.ago,
          method: "tools/call",
          tool: "discourse.search",
          outcome: "success",
        )
      McpAuditLog.create!(
        occurred_at: 1.minute.ago,
        method: "tools/call",
        tool: "discourse.other",
        outcome: "success",
      )
      newer_match =
        McpAuditLog.create!(
          occurred_at: Time.zone.now,
          method: "tools/call",
          tool: "discourse.search",
          outcome: "success",
        )

      get "/admin/mcp/activity.json", params: { filter: "search", limit: 1 }

      expect(response.parsed_body["activity"].map { |entry| entry["id"] }).to eq([newer_match.id])
      cursor = response.parsed_body.dig("meta", "next_cursor")
      expect(cursor).to eq(newer_match.id)
      expect(response.parsed_body).to have_key("metrics")

      get "/admin/mcp/activity.json", params: { filter: "search", limit: 1, cursor: cursor }

      expect(response.parsed_body["activity"].map { |entry| entry["id"] }).to eq([older_match.id])
      expect(response.parsed_body).not_to have_key("metrics")
    end

    it "rejects invalid filter values" do
      get "/admin/mcp/activity.json", params: { outcome: "unknown" }
      expect(response.status).to eq(400)

      get "/admin/mcp/activity.json", params: { cursor: "not-an-id" }
      expect(response.status).to eq(400)

      get "/admin/mcp/activity.json", params: { filter: "a" * 201 }
      expect(response.status).to eq(400)
    end

    it "does not allow moderators to view MCP activity" do
      sign_in(Fabricate(:moderator))

      get "/admin/mcp/activity.json"

      expect(response.status).to eq(404)
    end
  end
end
