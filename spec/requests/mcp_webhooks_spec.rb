# frozen_string_literal: true

describe "MCP webhook tools" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:scope_group, :group)
  fab!(:web_hook)
  fab!(:event) do
    Fabricate(
      :web_hook_event,
      web_hook:,
      headers: { "Content-Type" => "application/json", "X-Discourse-Event-Type" => "post" }.to_json,
    )
  end

  before do
    SiteSetting.mcp_server_enabled = true
    operations.each_key do |identifier|
      McpPrimitive.create!(kind: "tool", identifier:, enabled: true)
    end
  end

  def authorize(actor = admin, scopes: %w[mcp:webhooks:read mcp:webhooks:write])
    scope_group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Webhook tools",
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

  def identity
    { webhook_id: web_hook.id, expected_destination_fingerprint: web_hook.destination_fingerprint }
  end

  def create_arguments
    {
      payload_url: "https://meta.discourse.org/new-listener",
      content_type: "application/json",
      event_type_ids: [WebHookEventType::TYPES[:post_created]],
      confirm_external_delivery: true,
    }
  end

  def update_arguments
    identity.merge(expected_active: web_hook.active, confirm_update: true)
  end

  def operations
    {
      "discourse_list_webhooks" => {
      },
      "discourse_get_webhook" => {
        webhook_id: web_hook.id,
      },
      "discourse_list_webhook_events" => {
        webhook_id: web_hook.id,
      },
      "discourse_create_webhook" => create_arguments,
      "discourse_update_webhook" => update_arguments.merge(active: false),
      "discourse_delete_webhook" => identity.merge(confirm_delete: true),
      "discourse_ping_webhook" => identity.merge(confirm_external_request: true),
      "discourse_redeliver_webhook_event" =>
        identity.merge(
          event_id: event.id,
          expected_event_status: event.status,
          confirm_redelivery: true,
        ),
    }
  end

  it "registers separate scopes and accurate side-effect annotations" do
    operations.each_key do |name|
      tool = DiscourseMcp.registry.find(:tool, name)
      expect(tool).not_to be_nil
      read = %w[
        discourse_list_webhooks
        discourse_get_webhook
        discourse_list_webhook_events
      ].include?(name)
      expect(tool.required_scopes).to eq([read ? "mcp:webhooks:read" : "mcp:webhooks:write"])
      expect(tool.annotations["readOnlyHint"]).to eq(read)
    end
    %w[discourse_ping_webhook discourse_redeliver_webhook_event].each do |name|
      expect(DiscourseMcp.registry.find(:tool, name).annotations).to include(
        "openWorldHint" => true,
        "idempotentHint" => false,
      )
    end
    expect(DiscourseMcp.registry.find(:tool, "discourse_redeliver_webhook_event")).to be_deferred
  end

  it "requires authentication" do
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(401), name
    end
  end

  it "denies moderators and regular users even with both scopes" do
    [moderator, user].each do |actor|
      authorize(actor)
      operations.each do |name, arguments|
        call_tool(name, arguments)
        expect(response.status).to eq(403), name
      end
    end
    expect(web_hook.reload.active).to eq(true)
    expect(WebHook.count).to eq(1)
  end

  it "requires the relevant scope even for administrators" do
    authorize(scopes: [])
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403), name
    end
  end

  it "does not let the write scope grant configuration or delivery-history reads" do
    authorize(scopes: ["mcp:webhooks:write"])
    %w[discourse_list_webhooks discourse_get_webhook discourse_list_webhook_events].each do |name|
      call_tool(name, operations[name])
      expect(response.status).to eq(403)
    end
  end

  it "does not let the read scope grant mutations" do
    authorize(scopes: ["mcp:webhooks:read"])
    call_tool("discourse_list_webhooks")
    expect(response.status).to eq(200)
    call_tool("discourse_create_webhook", create_arguments)
    expect(response.status).to eq(403)
  end

  it "does not return signing secrets or credential-bearing destination paths and queries" do
    web_hook.update!(payload_url: "https://meta.discourse.org/path-secret?api_key=query-secret")
    authorize
    %w[discourse_get_webhook discourse_list_webhooks].each do |name|
      call_tool(name, webhook_id: web_hook.id) if name == "discourse_get_webhook"
      call_tool(name) if name == "discourse_list_webhooks"
      expect(response.status).to eq(200)
      expect(response.body).not_to include(web_hook.secret, "path-secret", "query-secret")
    end
    result = response.parsed_body.dig("result", "structuredContent", "webhooks", 0)
    expect(result).to include(
      "destination_origin" => "https://meta.discourse.org",
      "destination_fingerprint" => web_hook.destination_fingerprint,
      "secret_configured" => true,
    )
  end

  it "filters signing secrets and complete destinations from request logs" do
    parameters = {
      "params" => {
        "arguments" => {
          "webhook_id" => web_hook.id,
          "secret" => web_hook.secret,
          "payload_url" => web_hook.payload_url,
        },
      },
    }
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)
    expect(filter.filter(parameters).dig("params", "arguments")).to eq(
      "webhook_id" => web_hook.id,
      "secret" => "[FILTERED]",
      "payload_url" => "[FILTERED]",
    )
  end

  it "returns the live event catalog and paginates configurations without duplicates" do
    other = Fabricate(:inactive_web_hook)
    authorize
    call_tool("discourse_list_webhooks", limit: 1, include_catalog: true)
    result = response.parsed_body.dig("result", "structuredContent")
    expect(result["webhooks"].map { |hook| hook["id"] }).to eq([web_hook.id])
    expect(result).to include("has_more" => true, "next_offset" => 1)
    expect(result.dig("catalog", "event_types").map { |type| type["id"] }).to include(
      WebHookEventType::TYPES[:post_created],
    )
    expect(result.dig("catalog", "content_types")).to include("application/json")
    call_tool("discourse_list_webhooks", offset: 1, limit: 1)
    expect(response.parsed_body.dig("result", "structuredContent", "webhooks", 0, "id")).to eq(
      other.id,
    )
    call_tool("discourse_list_webhooks", delivery_status: "disabled")
    expect(
      response.parsed_body.dig("result", "structuredContent", "webhooks").map { |h| h["id"] },
    ).to eq([other.id])
  end

  it "keeps relationship queries bounded when more webhooks are listed" do
    tag = Fabricate(:tag)
    group = Fabricate(:group)
    category = Fabricate(:category)
    web_hook.update!(tags: [tag], groups: [group], categories: [category])
    authorize
    call_tool("discourse_list_webhooks")
    initial_queries = track_sql_queries { call_tool("discourse_list_webhooks") }
    5.times { Fabricate(:web_hook, tags: [tag], groups: [group], categories: [category]) }
    expanded_queries = track_sql_queries { call_tool("discourse_list_webhooks") }
    expect(response.parsed_body.dig("result", "structuredContent", "webhooks").length).to eq(6)
    expect(expanded_queries.length).to be <= initial_queries.length + 1
  end

  it "creates inactive hooks by default and logs the operation without secret values" do
    authorize
    call_tool(
      "discourse_create_webhook",
      create_arguments.merge(
        secret: "new-signing-secret",
        payload_url: "https://meta.discourse.org/path-secret?api_key=query-secret",
      ),
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    created = WebHook.order(:id).last
    expect(created).to have_attributes(
      active: false,
      verify_certificate: true,
      secret: "new-signing-secret",
    )
    expect(created.web_hook_event_type_ids).to eq([WebHookEventType::TYPES[:post_created]])
    history = UserHistory.where(action: UserHistory.actions[:web_hook_create]).last
    expect(history.acting_user_id).to eq(admin.id)
    expect(history.admin_only).to eq(true)
    expect([history.context, history.details, history.new_value].join).not_to include(
      "new-signing-secret",
      "path-secret",
      "query-secret",
    )
    expect(history.details).to include(
      "destination_origin: https://meta.discourse.org",
      "destination_fingerprint: #{created.destination_fingerprint}",
    )
    expect(response.body).not_to include("new-signing-secret")
  end

  it "creates functional wildcard hooks without explicit event subscriptions" do
    authorize
    call_tool(
      "discourse_create_webhook",
      create_arguments.merge(
        wildcard_web_hook: true,
        event_type_ids: [],
        confirm_wildcard: true,
        active: true,
        confirm_activate: true,
      ),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    id = response.parsed_body.dig("result", "structuredContent", "webhook", "id")
    expect(WebHook.active_web_hooks(:user_created).pluck(:id)).to include(id)
  end

  it "requires explicit confirmation of external delivery and risky configuration" do
    authorize
    [
      create_arguments.merge(confirm_external_delivery: false),
      create_arguments.merge(active: true),
      create_arguments.merge(verify_certificate: false),
      create_arguments.merge(payload_url: "http://meta.discourse.org/listener"),
      create_arguments.merge(wildcard_web_hook: true, event_type_ids: []),
    ].each do |arguments|
      expect { call_tool("discourse_create_webhook", arguments) }.not_to change { WebHook.count }
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
  end

  it "rejects credential-bearing, malformed, and internal destinations" do
    authorize
    %w[
      https://user:password@meta.discourse.org/
      https://
      https://meta.discourse.org/#fragment
    ].each do |url|
      call_tool("discourse_create_webhook", create_arguments.merge(payload_url: url))
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(WebHook.count).to eq(1)
    end
    FinalDestination::TestHelper.stub_to_fail do
      call_tool("discourse_create_webhook", create_arguments)
    end
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(WebHook.count).to eq(1)
  end

  it "rejects unknown or disabled relationships before changing state" do
    authorize
    [
      { category_ids: [999_999] },
      { group_ids: [999_999] },
      { tag_ids: [999_999] },
      { event_type_ids: [999_999] },
    ].each do |attributes|
      call_tool("discourse_create_webhook", create_arguments.merge(attributes))
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(WebHook.count).to eq(1)
    end
  end

  it "preserves omitted fields during updates and validates destination and active-state preconditions" do
    tag = Fabricate(:tag)
    web_hook.tags << tag
    authorize
    call_tool("discourse_update_webhook", update_arguments.merge(active: false))
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload).to have_attributes(
      active: false,
      secret: "my_lovely_secret_for_web_hook",
    )
    expect(web_hook.tags).to contain_exactly(tag)
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(expected_active: true, active: true, confirm_activate: true),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.active).to eq(false)
  end

  it "requires explicit relationship replacement and secret clearing" do
    tag = Fabricate(:tag)
    web_hook.tags << tag
    authorize
    call_tool("discourse_update_webhook", update_arguments.merge(tag_ids: []))
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.tags).to contain_exactly(tag)
    call_tool("discourse_update_webhook", update_arguments.merge(secret: ""))
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.secret).to be_present
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(
        tag_ids: [],
        secret: "",
        confirm_scope_replacement: true,
        confirm_clear_secret: true,
      ),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.tags).to be_empty
    expect(web_hook.secret).to eq("")
  end

  it "requires confirmation before a blank signing secret disables signatures" do
    authorize
    original_secret = web_hook.secret
    call_tool("discourse_update_webhook", update_arguments.merge(secret: " \t\n"))
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.secret).to eq(original_secret)
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(secret: " ", confirm_clear_secret: true),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.secret).to be_blank
  end

  it "requires external-delivery confirmation when retargeting an active hook" do
    authorize
    original_url = web_hook.payload_url
    arguments = update_arguments.merge(payload_url: "https://meta.discourse.org/new-target")
    call_tool("discourse_update_webhook", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.payload_url).to eq(original_url)
    call_tool("discourse_update_webhook", arguments.merge(confirm_external_delivery: true))
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.payload_url).to eq(arguments[:payload_url])
  end

  it "requires clearing preserved subscriptions before enabling wildcard delivery" do
    authorize
    arguments = update_arguments.merge(wildcard_web_hook: true, confirm_wildcard: true)
    call_tool("discourse_update_webhook", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.wildcard_web_hook).to eq(false)
    call_tool(
      "discourse_update_webhook",
      arguments.merge(event_type_ids: [], confirm_scope_replacement: true),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.wildcard_web_hook).to eq(true)
    expect(web_hook.web_hook_event_type_ids).to be_empty
  end

  it "returns a tool error for a destination whose hostname cannot be resolved" do
    authorize
    allow(FinalDestination::SSRFDetector).to receive(:lookup_and_filter_ips).and_raise(
      FinalDestination::SSRFDetector::LookupFailedError,
    )
    expect { call_tool("discourse_create_webhook", create_arguments) }.to not_change(
      WebHook,
      :count,
    ).and(not_change(UserHistory, :count))
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "does not require a new delivery confirmation for an unchanged destination" do
    authorize
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(
        payload_url: web_hook.payload_url,
        secret: "replacement-signing-secret",
      ),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.secret).to eq("replacement-signing-secret")
  end

  it "allows retargeting an inactive hook without enabling delivery" do
    web_hook.update!(active: false)
    authorize
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(payload_url: "https://meta.discourse.org/inactive-target"),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload).to have_attributes(
      active: false,
      payload_url: "https://meta.discourse.org/inactive-target",
    )
  end

  it "requires external-delivery confirmation when retargeting and activating together" do
    web_hook.update!(active: false)
    authorize
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(
        payload_url: "https://meta.discourse.org/active-target",
        active: true,
        confirm_activate: true,
      ),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.active).to eq(false)
  end

  it "preserves legacy wildcard subscriptions during an unrelated partial update" do
    web_hook.update!(wildcard_web_hook: true)
    event_type_ids = web_hook.web_hook_event_type_ids
    authorize
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(secret: "replacement-signing-secret"),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(web_hook.reload.web_hook_event_type_ids).to eq(event_type_ids)
  end

  it "returns a tool error and preserves configuration when an updated hostname cannot resolve" do
    authorize
    original_url = web_hook.payload_url
    allow(FinalDestination::SSRFDetector).to receive(:lookup_and_filter_ips).and_raise(
      FinalDestination::SSRFDetector::LookupFailedError,
    )
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(
        payload_url: "https://meta.discourse.org/unreachable",
        confirm_external_delivery: true,
      ),
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(web_hook.reload.payload_url).to eq(original_url)
  end

  it "returns a tool error if a webhook disappears before its mutation lock" do
    authorize
    allow_any_instance_of(WebHook).to receive(:lock!).and_wrap_original do |method, *args|
      WebHook.where(id: method.receiver.id).delete_all
      method.call(*args)
    end
    %w[discourse_update_webhook discourse_delete_webhook].each do |name|
      hook = Fabricate(:web_hook)
      arguments =
        operations[name].merge(
          webhook_id: hook.id,
          expected_destination_fingerprint: hook.destination_fingerprint,
        )
      call_tool(name, arguments)
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(response.parsed_body.dig("result", "content", 0, "text")).to include(
        I18n.t("mcp.errors.webhook_not_found"),
      )
    end
  end

  it "rolls back webhook and association changes when a staff log fails" do
    tag = Fabricate(:tag)
    web_hook.tags << tag
    allow_any_instance_of(StaffActionLogger).to receive(:log_web_hook_operation).and_raise(
      "log unavailable",
    )
    authorize
    call_tool(
      "discourse_update_webhook",
      update_arguments.merge(active: false, tag_ids: [], confirm_scope_replacement: true),
    )
    expect(response.status).to eq(500)
    expect(web_hook.reload.active).to eq(true)
    expect(web_hook.tags).to contain_exactly(tag)
  end

  it "rejects empty or ineffective updates" do
    authorize
    [update_arguments, update_arguments.merge(active: web_hook.active)].each do |arguments|
      call_tool("discourse_update_webhook", arguments)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
  end

  it "requires the current destination and confirmation before deletion" do
    authorize
    call_tool("discourse_delete_webhook", identity.merge(confirm_delete: false))
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    call_tool(
      "discourse_delete_webhook",
      identity.merge(expected_destination_fingerprint: "0" * 64, confirm_delete: true),
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    marker = RedeliveringWebhookEvent.create!(web_hook_event: event)
    call_tool("discourse_delete_webhook", identity.merge(confirm_delete: true))
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(WebHook.exists?(web_hook.id)).to eq(false)
    expect(WebHookEvent.exists?(event.id)).to eq(false)
    expect(RedeliveringWebhookEvent.exists?(marker.id)).to eq(false)
    expect(
      UserHistory.where(action: UserHistory.actions[:web_hook_destroy], acting_user_id: admin.id),
    ).to exist
  end

  it "requires the private-message read scope before inspecting delivery bodies" do
    event.update!(
      payload: { post: { archetype: "private_message", raw: "private message text" } }.to_json,
    )
    authorize(scopes: ["mcp:webhooks:read"])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include('scope="mcp:private-messages:read"')
    expect(response.body).not_to include("private message text")
  end

  it "omits delivery bodies and headers unless content inspection is explicitly confirmed" do
    event.update!(payload: { secret: web_hook.secret, raw: "private forum text" }.to_json)
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool("discourse_list_webhook_events", webhook_id: web_hook.id)
    expect(response.body).not_to include("private forum text", web_hook.secret, "Content-Type")
    call_tool("discourse_list_webhook_events", webhook_id: web_hook.id, include_content: true)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    expect(response.body).to include("private forum text")
    expect(response.body).not_to include(web_hook.secret)
    expect(
      response.parsed_body.dig(
        "result",
        "structuredContent",
        "events",
        0,
        "request_payload_preview",
      ),
    ).to include("[FILTERED]")
  end

  it "does not leak JSON-escaped signing secrets in confirmed content previews" do
    secret = "signing-\"quoted\"-secret\\with\nnewline"
    web_hook.update!(secret:)
    event.update!(payload: { raw: secret, url: web_hook.payload_url }.to_json)
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    preview =
      response.parsed_body.dig(
        "result",
        "structuredContent",
        "events",
        0,
        "request_payload_preview",
      )
    expect(JSON.parse(preview)).to eq("raw" => "[FILTERED]", "url" => "[FILTERED]")
  end

  it "bounds previews, omits unstructured bodies, and filters delivery status before pagination" do
    event.update!(payload: { raw: "x" * 1000 }.to_json, response_body: "unstructured secret")
    failed = Fabricate(:web_hook_event, web_hook:, status: 500)
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      status: "successful",
      limit: 1,
      include_content: true,
      confirm_sensitive_content: true,
      content_limit: 100,
    )
    result = response.parsed_body.dig("result", "structuredContent")
    expect(result["events"].map { |e| e["id"] }).to eq([event.id])
    expect(result["events"].first["request_payload_preview"].length).to eq(100)
    expect(result["events"].first["response_body_preview"]).to be_nil
    expect(result["events"].first["content_truncated"]).to eq(true)
    expect(response.body).not_to include("unstructured secret")
    call_tool("discourse_list_webhook_events", webhook_id: web_hook.id, status: "failed")
    expect(
      response.parsed_body.dig("result", "structuredContent", "events").map { |e| e["id"] },
    ).to eq([failed.id])
  end

  it "omits oversized JSON bodies from content previews" do
    event.update!(payload: { raw: "x" * 100_000 }.to_json)
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    result = response.parsed_body.dig("result", "structuredContent", "events", 0)
    expect(result["request_payload_preview"]).to be_nil
    expect(result["content_omitted"]).to eq(true)
  end

  it "redacts complete destinations before overlapping signing secrets" do
    secret = "my-lovely-secret-path"
    url = "https://meta.discourse.org/#{secret}?api_key=delivery-token"
    web_hook.update!(secret:, payload_url: url)
    event.update!(payload: { raw: url }.to_json)
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    preview =
      response.parsed_body.dig(
        "result",
        "structuredContent",
        "events",
        0,
        "request_payload_preview",
      )
    expect(JSON.parse(preview)).to eq("raw" => "[FILTERED]")
  end

  it "filters current destination paths and standalone query credentials from previews" do
    web_hook.update!(
      payload_url: "https://meta.discourse.org/T1/B2/current-token?api_key=delivery-token&page=1",
    )
    event.update!(
      response_body: {
        error: "Cannot POST /T1/B2/current-token",
        detail: "delivery-token",
        public: "Page 1 is unchanged",
      }.to_json,
    )
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    preview =
      response.parsed_body.dig("result", "structuredContent", "events", 0, "response_body_preview")
    expect(JSON.parse(preview)).to eq(
      "error" => "Cannot POST [FILTERED]",
      "detail" => "[FILTERED]",
      "public" => "Page 1 is unchanged",
    )
  end

  it "omits malformed Unicode keys and values without losing the history page" do
    event.update!(payload: %q({"a":"\ud800"}), response_body: %q({"\ud800":1}))
    authorize(scopes: %w[mcp:webhooks:read mcp:private-messages:read])
    call_tool(
      "discourse_list_webhook_events",
      webhook_id: web_hook.id,
      include_content: true,
      confirm_sensitive_content: true,
    )
    expect(response.status).to eq(200)
    result = response.parsed_body.dig("result", "structuredContent", "events", 0)
    expect(result).to include(
      "id" => event.id,
      "request_payload_preview" => nil,
      "response_body_preview" => nil,
      "content_omitted" => true,
    )
  end

  it "uses the existing webhook retry behavior for pings" do
    SiteSetting.retry_web_hook_events = true
    authorize
    call_tool("discourse_ping_webhook", identity.merge(confirm_external_request: true))
    args = Jobs::EmitWebHookEvent.jobs.last["args"].first.deep_symbolize_keys
    request = stub_request(:post, web_hook.payload_url).to_return(status: 500)
    expect { Jobs::EmitWebHookEvent.new.execute(args) }.to change {
      Jobs::EmitWebHookEvent.jobs.length
    }.by(1)
    expect(Jobs::EmitWebHookEvent.jobs.last["args"].first).to include(
      "expected_destination_fingerprint" => web_hook.destination_fingerprint,
    )
    expect(request).to have_been_requested.once
  end

  it "queues pings without claiming delivery success and records the request" do
    authorize
    expect {
      call_tool("discourse_ping_webhook", identity.merge(confirm_external_request: true))
    }.to change { Jobs::EmitWebHookEvent.jobs.length }.by(1)
    expect(response.parsed_body.dig("result", "structuredContent")).to include(
      "enqueued" => true,
      "delivery_succeeded" => nil,
    )
    expect(Jobs::EmitWebHookEvent.jobs.last["args"].first).to include(
      "web_hook_id" => web_hook.id,
      "event_type" => "ping",
    )
    expect(
      UserHistory.where(action: UserHistory.actions[:web_hook_ping], acting_user_id: admin.id),
    ).to exist
  end

  it "does not send a queued ping to a destination changed after confirmation" do
    authorize
    call_tool("discourse_ping_webhook", identity.merge(confirm_external_request: true))
    args = Jobs::EmitWebHookEvent.jobs.last["args"].first.deep_symbolize_keys
    web_hook.update!(payload_url: "https://meta.discourse.org/different-listener")
    request = stub_request(:post, web_hook.payload_url).to_return(status: 200)

    Jobs::EmitWebHookEvent.new.execute(args)

    expect(request).not_to have_been_requested
  end

  it "does not queue pings when confirmation or destination identity is stale" do
    authorize
    expect {
      call_tool("discourse_ping_webhook", identity.merge(confirm_external_request: false))
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      call_tool(
        "discourse_ping_webhook",
        identity.merge(confirm_external_request: true, expected_destination_fingerprint: "0" * 64),
      )
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    }.not_to change { Jobs::EmitWebHookEvent.jobs.length }
  end

  it "redelivers exactly the selected event with the existing emitter" do
    event.update!(payload: '{"post":{"raw":"private payload"}}')
    request =
      stub_request(:post, web_hook.payload_url).with(body: event.payload).to_return(status: 202)
    authorize
    call_tool("discourse_redeliver_webhook_event", operations["discourse_redeliver_webhook_event"])
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).to include(
      "attempted" => true,
      "delivery_succeeded" => true,
    )
    expect(event.reload.status).to eq(202)
    expect(request).to have_been_requested.once
    expect(response.body).not_to include("private payload", web_hook.secret)
    expect(
      UserHistory.where(action: UserHistory.actions[:web_hook_redeliver], acting_user_id: admin.id),
    ).to exist
  end

  it "rejects an overlapping native redelivery even when the status stays failed" do
    event.update!(status: 500)
    authorize
    arguments = operations["discourse_redeliver_webhook_event"]
    nested_error = nil
    attempts = 0
    request =
      stub_request(:post, web_hook.payload_url).to_return do
        attempts += 1
        if attempts == 1
          begin
            DiscourseMcp::Tools::RedeliverWebhookEvent.call(
              arguments: arguments.stringify_keys,
              request_context: Struct.new(:guardian).new(admin.guardian),
            )
          rescue DiscourseMcp::ToolError => error
            nested_error = error
          end
        end
        { status: 500 }
      end
    expect { call_tool("discourse_redeliver_webhook_event", arguments) }.to change {
      UserHistory.where(action: UserHistory.actions[:web_hook_redeliver]).count
    }.by(1)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(nested_error).to be_a(DiscourseMcp::ToolError)
    expect(request).to have_been_requested.once
    expect(event.reload.status).to eq(500)
    expect(RedeliveringWebhookEvent.where(web_hook_event_id: event.id)).not_to exist
  end

  it "reports the delivery outcome when the webhook is deleted during the request" do
    authorize
    request =
      stub_request(:post, web_hook.payload_url).to_return do
        WebHook.find(web_hook.id).destroy!
        { status: 202 }
      end
    call_tool("discourse_redeliver_webhook_event", operations["discourse_redeliver_webhook_event"])
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).to include(
      "attempted" => true,
      "delivery_succeeded" => true,
    )
    expect(WebHook.exists?(web_hook.id)).to eq(false)
    expect(RedeliveringWebhookEvent.where(web_hook_event_id: event.id)).not_to exist
    expect(request).to have_been_requested.once
  end

  it "preserves an existing queued marker when rejecting redelivery" do
    marker = RedeliveringWebhookEvent.create!(web_hook_event: event)
    authorize
    request = stub_request(:post, web_hook.payload_url).to_return(status: 200)
    call_tool("discourse_redeliver_webhook_event", operations["discourse_redeliver_webhook_event"])
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(marker.reload.processing).to eq(false)
    expect(request).not_to have_been_requested
  end

  it "releases its redelivery claim when the emitter raises" do
    authorize
    allow_any_instance_of(WebHookEmitter).to receive(:emit!).and_raise("emitter unavailable")
    call_tool("discourse_redeliver_webhook_event", operations["discourse_redeliver_webhook_event"])
    expect(response.status).to eq(500)
    expect(RedeliveringWebhookEvent.where(web_hook_event_id: event.id)).not_to exist
  end

  it "checks event ownership, status, and ping identity before any redelivery" do
    other = Fabricate(:web_hook_event)
    authorize
    [
      operations["discourse_redeliver_webhook_event"].merge(event_id: other.id),
      operations["discourse_redeliver_webhook_event"].merge(expected_event_status: 500),
    ].each do |arguments|
      call_tool("discourse_redeliver_webhook_event", arguments)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
    event.update!(headers: { "X-Discourse-Event-Type" => "ping" }.to_json)
    call_tool("discourse_redeliver_webhook_event", operations["discourse_redeliver_webhook_event"])
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(WebMock).not_to have_requested(:post, web_hook.payload_url)
  end

  it "retains outbound SSRF filtering on redelivery" do
    authorize
    FinalDestination::TestHelper.stub_to_fail do
      call_tool(
        "discourse_redeliver_webhook_event",
        operations["discourse_redeliver_webhook_event"],
      )
    end
    expect(response.parsed_body.dig("result", "structuredContent", "delivery_succeeded")).to eq(
      false,
    )
    expect(event.reload.status).to eq(-1)
    expect(WebMock).not_to have_requested(:post, web_hook.payload_url)
  end

  it "rejects malformed and oversized inputs before mutation" do
    authorize
    [
      { category_ids: Array.new(101, 1) },
      { tag_ids: [1, 1] },
      { active: "true" },
      { content_type: "text/plain" },
      { payload_url: "x" * 2049 },
      { secret: "x" * 1025 },
    ].each do |attributes|
      call_tool("discourse_create_webhook", create_arguments.merge(attributes))
      expect(response.status).to eq(400), attributes.inspect
    end
    expect(WebHook.count).to eq(1)
  end
end
