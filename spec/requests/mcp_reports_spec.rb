# frozen_string_literal: true

describe "MCP report tools" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:scope_group, :group)

  before do
    SiteSetting.mcp_server_enabled = true
    %w[discourse_list_reports discourse_get_report].each do |identifier|
      McpPrimitive.create!(kind: "tool", identifier:, enabled: true)
    end
  end

  def authorize(actor = admin, scopes: ["mcp:reports:read"])
    scope_group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Report tools",
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
           "HTTP_MCP_METHOD" => "tools/call",
           "HTTP_MCP_NAME" => name,
         }
  end

  def operations
    { "discourse_list_reports" => {}, "discourse_get_report" => { report_type: "topics" } }
  end

  it "registers read-only report tools with a dedicated scope and deferred execution" do
    operations.each_key do |name|
      tool = DiscourseMcp.registry.find(:tool, name)
      expect(tool).not_to be_nil
      expect(tool.required_scopes).to eq(["mcp:reports:read"])
      expect(tool.annotations).to include("readOnlyHint" => true, "destructiveHint" => false)
    end
    expect(DiscourseMcp.registry.find(:tool, "discourse_get_report")).to be_deferred
  end

  it "requires authentication" do
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(401)
    end
  end

  it "requires the report scope even when other staff read scopes are granted" do
    authorize(scopes: %w[mcp:content:read mcp:moderation:read mcp:site-settings:read])
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403)
      expect(response.headers["WWW-Authenticate"]).to include('scope="mcp:reports:read"')
    end
  end

  it "does not let report scopes give a regular user staff permissions" do
    authorize(user)
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403)
    end
  end

  it "uses the shared catalog for admins and moderators" do
    [admin, moderator].each do |actor|
      authorize(actor)
      call_tool("discourse_list_reports")
      expect(response.status).to eq(200)
      reports = response.parsed_body.dig("result", "structuredContent", "reports")
      expect(reports).to eq(Reports::ListQuery.call(guardian: actor.guardian).as_json)
      expect(reports.map { |report| report["type"] }).to include("topics")
    end
  end

  it "denies moderators access to admin-only reports" do
    authorize(moderator)
    call_tool("discourse_get_report", report_type: "admin_logins")
    expect(response.parsed_body.dig("result", "isError")).to eq(true)

    authorize
    call_tool("discourse_get_report", report_type: "admin_logins")
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(response.parsed_body.dig("result", "structuredContent", "report", "type")).to eq(
      "admin_logins",
    )
  end

  it "returns report data with date ranges, facets, and typed category filters" do
    freeze_time
    category = Fabricate(:category)
    other_category = Fabricate(:category)
    Fabricate(:topic, category:, created_at: 2.days.ago)
    Fabricate(:topic, category: other_category, created_at: 2.days.ago)
    authorize(moderator)
    start_date = 3.days.ago.to_date.iso8601
    end_date = Date.current.iso8601
    call_tool(
      "discourse_get_report",
      report_type: "topics",
      start_date:,
      end_date:,
      facets: ["prev_period"],
      filters: {
        category: category.id,
        include_subcategories: false,
      },
      limit: 10,
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].sum { |row| row["y"] }).to eq(1)
    expect(report["start_date"].to_date.iso8601).to eq(start_date)
    expect(report["end_date"].to_date.iso8601).to eq(end_date)
    expect(report["limit"]).to eq(10)
    expect(report["prev_period"]).to eq(0)
  end

  it "uses a bounded default date range ending on the supplied end date" do
    authorize
    call_tool("discourse_get_report", report_type: "topics", end_date: "2026-01-31")
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["start_date"].to_date).to eq(Date.new(2026, 1, 1))
    expect(report["end_date"].to_date).to eq(Date.new(2026, 1, 31))
  end

  it "does not expose reports missing from the current catalog" do
    authorize
    %w[
      unknown_report
      about
      storage_stats
      suspicious_logins
      posters_by_member_type_members
    ].each do |type|
      call_tool("discourse_get_report", report_type: type)
      expect(response.parsed_body.dig("result", "isError")).to eq(true), type
    end

    SiteSetting.use_legacy_pageviews = true
    call_tool("discourse_get_report", report_type: "site_traffic")
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "rejects invalid dates, reversed ranges, and ranges longer than a year" do
    authorize
    [
      { start_date: "2026-02-30" },
      { start_date: "2026-02-02", end_date: "2026-02-01" },
      { start_date: "2024-01-01", end_date: "2026-01-01" },
    ].each do |dates|
      call_tool("discourse_get_report", { report_type: "topics" }.merge(dates))
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
  end

  it "accepts a 366-day inclusive range and rejects one additional day" do
    authorize
    call_tool(
      "discourse_get_report",
      report_type: "topics",
      start_date: "2024-01-01",
      end_date: "2024-12-31",
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)

    call_tool(
      "discourse_get_report",
      report_type: "topics",
      start_date: "2024-01-01",
      end_date: "2025-01-01",
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.parsed_body.dig("result", "content", 0, "text")).to eq(
      I18n.t("mcp.errors.report_date_range", count: 366),
    )
  end

  it "rejects malformed and oversized report inputs" do
    authorize
    [
      { report_type: "../topics" },
      { report_type: "topics\n" },
      { start_date: "20260101" },
      { limit: 0 },
      { limit: 51 },
      { facets: Array.new(21, "total") },
      { filters: { category: { id: 1 } } },
      { filters: { category_ids: Array.new(101, 1) } },
    ].each do |attributes|
      call_tool("discourse_get_report", { report_type: "topics" }.merge(attributes))
      expect(response.status).to eq(400), attributes.inspect
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
    end
  end

  it "preserves each report's default row limit when no limit is supplied" do
    allow(DiscourseIpInfo).to receive(:get).and_return(location: "Local")
    25.times do |index|
      UserAuthToken.log(
        action: "generate",
        user_id: admin.id,
        client_ip: "192.0.2.#{index + 1}",
        created_at: 1.hour.ago,
      )
    end
    authorize
    call_tool("discourse_get_report", report_type: "admin_logins")
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].length).to eq(20)
    expect(report).not_to have_key("limit")
  end

  it "requires administrator access to opt into the shared report cache" do
    authorize(moderator)
    call_tool("discourse_get_report", report_type: "topics", cache: true)
    expect(response.status).to eq(403)

    call_tool("discourse_get_report", report_type: "topics")
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
  end

  it "does not replay privileged cached rows after an administrator becomes a moderator" do
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    Fabricate(:category_activity_daily_rollup, category: private_category, date: 1.day.ago)
    authorize
    call_tool("discourse_get_report", report_type: "activity_by_category", cache: true)
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].map { |row| row["category_id"] }).to include(private_category.id)

    admin.update!(admin: false, moderator: true)
    Group.refresh_automatic_groups_for_user!(admin)
    call_tool("discourse_get_report", report_type: "activity_by_category", cache: true)
    expect(response.status).to eq(403)

    call_tool("discourse_get_report", report_type: "activity_by_category")
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].map { |row| row["category_id"] }).not_to include(private_category.id)
  end

  it "uses the shared cache only when requested" do
    category = Fabricate(:category)
    Fabricate(:topic, category:, created_at: 1.day.ago)
    authorize
    arguments = { report_type: "topics", filters: { category: category.id }, cache: true }
    call_tool("discourse_get_report", arguments)
    first_report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(first_report["data"].sum { |row| row["y"] }).to eq(1)

    Fabricate(:topic, category:, created_at: 1.day.ago)
    call_tool("discourse_get_report", arguments)
    expect(response.parsed_body.dig("result", "structuredContent", "report")).to eq(first_report)

    call_tool("discourse_get_report", arguments.merge(cache: false))
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].sum { |row| row["y"] }).to eq(2)
  end

  it "passes the caller's permissions to reports that restrict category data" do
    category = Fabricate(:category)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    Fabricate(:category_activity_daily_rollup, category:, date: 1.day.ago, topics: 1)
    Fabricate(
      :category_activity_daily_rollup,
      category: private_category,
      date: 1.day.ago,
      topics: 1,
    )
    authorize(moderator)
    call_tool("discourse_get_report", report_type: "activity_by_category")
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].map { |row| row["category_id"] }).to include(category.id)
    expect(report["data"].map { |row| row["category_id"] }).not_to include(private_category.id)

    authorize
    call_tool("discourse_get_report", report_type: "activity_by_category", cache: true)
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report["data"].map { |row| row["category_id"] }).to include(
      category.id,
      private_category.id,
    )
  end

  it "keeps admin-only related items out of moderator reports" do
    recent_user = Fabricate(:user, created_at: 1.day.ago)
    group = Fabricate(:group)
    group.add(recent_user)
    authorize(moderator)
    call_tool(
      "discourse_get_report",
      report_type: "signups",
      include_related_items: true,
      filters: {
        group: group.id,
      },
    )
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report).not_to have_key("related_items")

    authorize
    call_tool(
      "discourse_get_report",
      report_type: "signups",
      include_related_items: true,
      filters: {
        group: group.id,
      },
      limit: 1,
    )
    report = response.parsed_body.dig("result", "structuredContent", "report")
    expect(report.dig("related_items", "users").length).to eq(1)
    expect(report.dig("related_items", "users", 0, "user", "id")).to eq(recent_user.id)
  end

  context "with a registered plugin report" do
    let(:plugin) { Plugin::Instance.new }

    before do
      Discourse.plugins_by_name["mcp-test-reports"] = plugin
      allow(plugin).to receive(:enabled?).and_return(true)
      allow(plugin).to receive(:humanized_name).and_return("Test reports")
      I18n.backend.store_translations(
        :en,
        reports: {
          :mcp_test_report => {
            title: "Test report",
          },
          "mcp-test-report" => {
            title: "Hyphenated report",
          },
        },
      )
      Report.class_eval <<~RUBY, Rails.root.join("plugins/mcp-test-reports/plugin.rb").to_s, 1
        %w[mcp_test_report mcp-test-report].each do |type|
          add_report(type) do |report|
            report.data = [{ x: "plugin", y: 1 }]
            report.add_filter("category_ids", type: "category_list", default: report.filters[:category_ids])
          end
        end
      RUBY
    end

    after do
      %w[mcp_test_report mcp-test-report].each { |type| Report.remove_report(type) }
      Discourse.plugins_by_name.delete("mcp-test-reports")
      I18n.reload!
    end

    it "lists and executes plugin reports without a plugin-specific tool" do
      authorize
      call_tool("discourse_list_reports")
      reports = response.parsed_body.dig("result", "structuredContent", "reports")
      expect(reports).to include(
        a_hash_including("type" => "mcp_test_report", "plugin" => "mcp-test-reports"),
      )
      call_tool(
        "discourse_get_report",
        report_type: "mcp_test_report",
        filters: {
          category_ids: [1, 2],
        },
      )
      report = response.parsed_body.dig("result", "structuredContent", "report")
      expect(report["data"]).to eq([{ "x" => "plugin", "y" => 1 }])
      expect(report["available_filters"]).to include(
        "id" => "category_ids",
        "type" => "category_list",
        "default" => %w[1 2],
      )
    end

    it "retrieves listed plugin reports whose identifiers contain hyphens" do
      authorize
      call_tool("discourse_list_reports")
      reports = response.parsed_body.dig("result", "structuredContent", "reports")
      expect(reports.map { |report| report["type"] }).to include("mcp-test-report")
      call_tool("discourse_get_report", report_type: "mcp-test-report")
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "structuredContent", "report", "type")).to eq(
        "mcp-test-report",
      )
    end

    it "normalizes timestamp values in fresh and cached report payloads" do
      timestamp = Time.utc(2026, 1, 1, 12, 34, 56)
      Report.add_report("mcp_test_report") { |report| report.data = [{ created_at: timestamp }] }
      authorize
      [false, true, true].each do |cache|
        call_tool("discourse_get_report", report_type: "mcp_test_report", cache:)
        expect(response.status).to eq(200)
        structured_report = response.parsed_body.dig("result", "structuredContent", "report")
        expect(structured_report.dig("data", 0, "created_at")).to eq(timestamp.iso8601(3))
        text_report = JSON.parse(response.parsed_body.dig("result", "content", 0, "text"))
        expect(text_report["report"]).to eq(structured_report)
      end
    end

    it "checks plugin availability before returning a cached report" do
      authorize
      call_tool("discourse_get_report", report_type: "mcp_test_report", cache: true)
      expect(response.parsed_body.dig("result", "isError")).to eq(false)
      allow(plugin).to receive(:enabled?).and_return(false)

      call_tool("discourse_list_reports")
      reports = response.parsed_body.dig("result", "structuredContent", "reports")
      expect(reports.map { |report| report["type"] }).not_to include("mcp_test_report")
      call_tool("discourse_get_report", report_type: "mcp_test_report", cache: true)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end

    it "returns a tool error without exposing report exception details" do
      Report.add_report("mcp_test_report") { |_report| raise "private report details" }
      authorize
      call_tool("discourse_get_report", report_type: "mcp_test_report")
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(response.parsed_body.dig("result", "content", 0, "text")).to eq(
        I18n.t("mcp.errors.report_failed"),
      )
    end

    it "returns a tool error for a timed-out report" do
      allow(Report).to receive(:wrap_slow_query).and_raise(ActiveRecord::QueryCanceled)
      authorize
      call_tool("discourse_get_report", report_type: "mcp_test_report", cache: false)
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(response.parsed_body.dig("result", "content", 0, "text")).to eq(
        I18n.t("mcp.errors.report_timeout"),
      )
    end
  end
end
