# frozen_string_literal: true

describe DiscourseMcp::Server do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:recipient) { Fabricate(:user, username: "mcp_#{SecureRandom.hex(8)}") }
  let(:canary) { "mcpsecret#{SecureRandom.hex(10)}" }
  let(:message) do
    Fabricate(
      :private_message_post,
      user: admin,
      recipient:,
      raw: "Confidential orchardwitness body #{canary}",
    ).tap { |post| post.topic.update!(title: "Confidential subject #{canary}") }
  end
  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Content policy oracle",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: ["http://127.0.0.1/callback"],
    )
  end
  let(:authorization) do
    DiscourseMcp::OAuth::AuthorizationGrant.create!(
      user: admin,
      client:,
      redirect_uri: client.redirect_uris.first,
      requested_scopes: DiscourseMcp.registry.scopes,
    )
  end
  let(:raw_token) { McpOauthAccessToken.issue!(authorization:) }
  let(:token) { McpOauthAccessToken.find_by!(token_hash: McpOauthAccessToken.digest(raw_token)) }

  before do
    DiscourseMcp.reset_registry!
    SiteSetting.mcp_server_enabled = true
  end

  around do |example|
    original_registry = DiscourseMcp.registry
    example.run
  ensure
    DiscourseMcp.instance_variable_set(:@registry, original_registry)
  end

  def restrict_messages
    McpContentRule.create!(rule_kind: "private_messages", config: {})
  end

  def expose(kind, name)
    McpPrimitive.find_or_create_by!(kind: kind.to_s, identifier: name).update!(enabled: true)
    DiscourseMcp.registry.find(kind, name).tap { |registered| expect(registered).to be_present }
  end

  def rpc(method, params = {})
    request = ActionDispatch::TestRequest.create
    request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
    DiscourseMcp::Server.new(
      request:,
      request_context: DiscourseMcp::RequestContext.new(token),
    ).call(
      { "jsonrpc" => "2.0", "id" => 1, "method" => method, "params" => params.deep_stringify_keys },
    )
  end

  def tool(name, arguments = {})
    expose(:tool, name)
    rpc("tools/call", { name:, arguments: })
  end

  def serialized(response)
    JSON.generate(status: response.http_status, body: response.body, headers: response.headers)
  end

  def expect_no_private_content(response)
    expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
    expect(serialized(response)).not_to include(
      canary,
      message.raw,
      message.topic.title,
      message.full_url,
      recipient.username,
    )
  end

  def expect_blocked(response)
    expect(response.body.dig(:error, :message)).to eq(I18n.t("mcp.errors.content_policy_blocked"))
    expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
  end

  def expect_safe_or_blocked(response, primitive)
    expect(primitive.content).to be_a(Hash)
    expect_no_private_content(response)
    if DiscourseMcp.primitive_usable?(primitive)
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).not_to eq(true)
      yield response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
    else
      expect_blocked(response)
    end
  end

  it "[cr-u1] subtracts revoked scopes per request while preserving tokens grants OAuth and authorization status" do
    original_scopes = token.scopes.dup
    original_eligible = DiscourseMcp::Access.eligible_scopes(admin)
    expect(original_scopes).to include("mcp:private-messages:read", "mcp:private-messages:write")
    unrestricted_context = DiscourseMcp::RequestContext.new(token)
    rule = restrict_messages
    context = DiscourseMcp::RequestContext.new(token)
    revoked = %w[mcp:private-messages:read mcp:private-messages:write]

    expect(context.content_policy).to be_active
    expect(context.token_scopes.to_a).to match_array(original_scopes)
    expect(context.scopes.to_a).to match_array(original_scopes - revoked)
    expect(context.has_scopes?(revoked)).to eq(false)
    expect(unrestricted_context.has_scopes?(revoked)).to eq(true)
    expect(token.reload.scopes).to eq(original_scopes)
    expect(authorization.reload.scopes).to match_array(original_scopes)
    expect(DiscourseMcp::Access.eligible_scopes(admin)).to eq(original_eligible)
    expect(DiscourseMcp::AuthorizationStatus.for([authorization]).fetch(authorization.id)).to eq(
      "active",
    )
    request = ActionDispatch::TestRequest.create
    request.headers["Authorization"] = "Bearer #{raw_token}"
    authenticated = DiscourseMcp::Authenticator.new(request).authenticate!
    expect(authenticated.scopes.to_a).to match_array(original_scopes - revoked)
    result = tool("discourse_current_user_get").body.fetch(:result).fetch(:structuredContent)
    expect(result.fetch(:scopes)).to match_array(original_scopes - revoked)

    rule.destroy!
    expect(DiscourseMcp::RequestContext.new(token).scopes.to_a).to match_array(original_scopes)
    expect(DiscourseMcp::Authenticator.new(request).authenticate!.has_scopes?(revoked)).to eq(true)
  end

  it "[cr-u1] gives revoked scopes a caller-provided not-found error and preserves ordinary scope challenges" do
    restrict_messages
    context = DiscourseMcp::RequestContext.new(token)
    not_found = "Missing record #{SecureRandom.hex(8)}"
    expect do context.ensure_scopes!("mcp:private-messages:read", not_found:) end.to raise_error(
      DiscourseMcp::ToolError,
      not_found,
    )
    expect do context.ensure_scopes!("mcp:private-messages:write") end.to raise_error do |error|
      expect(error.message).to eq(I18n.t("mcp.errors.content_policy_blocked"))
      if error.respond_to?(:headers)
        expect(error.headers.keys.map(&:downcase)).not_to include("www-authenticate")
      end
    end
    reduced_token = token.dup
    reduced_token.scopes = [DiscourseMcp::INITIAL_SCOPE]
    reduced_context = DiscourseMcp::RequestContext.new(reduced_token)
    expect do reduced_context.ensure_scopes!("mcp:content:write", not_found:) end.to raise_error(
      DiscourseMcp::Error,
    ) do |error|
      expect(error.http_status).to eq(403)
      expect(error.headers.fetch("WWW-Authenticate")).to include('error="insufficient_scope"')
    end
  end

  it "[cr-u1] restores existing-token PM reads on the next server request after deleting the rule" do
    name = "discourse_read_private_message"
    expect(
      tool(name, topic_id: message.topic_id).body.dig(:result, :structuredContent, :title),
    ).to eq(message.topic.title)
    rule = restrict_messages
    expect_blocked(tool(name, topic_id: message.topic_id))
    rule.destroy!
    restored = tool(name, topic_id: message.topic_id)
    expect(restored.body.dig(:result, :structuredContent, :title)).to eq(message.topic.title)
    expect(serialized(restored)).to include(canary)
  end

  it "[cr-u1] hides every PM-scoped core tool and blocks calls before argument validation with policy audit outcomes" do
    restrict_messages
    pm_scopes = %w[mcp:private-messages:read mcp:private-messages:write]
    pm_tools =
      DiscourseMcp
        .registry
        .all(:tool)
        .select do |registered|
          registered.provider == "core" && (registered.required_scopes & pm_scopes).present?
        end
    expect(pm_tools.map(&:identifier)).to contain_exactly(
      "discourse_list_private_messages",
      "discourse_read_private_message",
      "discourse_create_private_message",
      "discourse_reply_private_message",
      "discourse_invite_to_private_message",
    )
    pm_tools.each { |registered| expose(:tool, registered.identifier) }
    expect(rpc("tools/list").body.dig(:result, :tools)).to eq([])
    pm_tools.each do |registered|
      aggregate_failures(registered.identifier) do
        response = tool(registered.identifier)
        expect_blocked(response)
        expect(McpAuditLog.last).to have_attributes(
          tool: registered.identifier,
          outcome: "content_policy_blocked",
        )
      end
    end
  end

  it "[cr-u1] excludes blocked tools resource templates and prompts and never invokes their implementations" do
    invoked = []
    registry = DiscourseMcp.registry
    %i[tool resource_template prompt].each do |kind|
      registry.public_send(
        "register_#{kind}",
        "oracle_blocked_#{kind}",
        title: "Blocked oracle",
        description: "Records invocation at the public boundary",
        content: :unbounded,
        implementation: ->(**) do
          invoked << kind
          raise "Blocked oracle ran"
        end,
      )
      expose(kind, "oracle_blocked_#{kind}")
    end
    expect(rpc("tools/list").body.dig(:result, :tools).pluck(:name)).to eq(["oracle_blocked_tool"])
    expect(
      rpc("resources/templates/list").body.dig(:result, :resourceTemplates).pluck(:name),
    ).to eq(["oracle_blocked_resource_template"])
    expect(rpc("prompts/list").body.dig(:result, :prompts).pluck(:name)).to eq(
      ["oracle_blocked_prompt"],
    )
    restrict_messages
    expect(rpc("tools/list").body.dig(:result, :tools)).to eq([])
    expect(rpc("resources/templates/list").body.dig(:result, :resourceTemplates)).to eq([])
    expect(rpc("prompts/list").body.dig(:result, :prompts)).to eq([])
    [
      ["tools/call", { name: "oracle_blocked_tool" }],
      ["prompts/get", { name: "oracle_blocked_prompt" }],
      ["resources/read", { uri: "discourse://oracle_blocked_resource_template/1" }],
    ].each { |method, params| aggregate_failures(method) { expect_blocked(rpc(method, params)) } }
    expect(invoked).to eq([])
  end

  it "[cr-u1] counts only usable exposed primitives for user eligibility" do
    name = "discourse_read_private_message"
    expose(:tool, name)
    expect(DiscourseMcp::Access.eligible_for_exposed_primitive?(admin)).to eq(true)
    restrict_messages
    expect(DiscourseMcp::Access.eligible_for_exposed_primitive?(admin)).to eq(false)
    expose(:tool, "discourse_current_user_get")
    expect(DiscourseMcp::Access.eligible_for_exposed_primitive?(admin)).to eq(true)
  end

  shared_examples "a PM identifier oracle" do |name, key, arguments|
    it "[cr-u1] makes #{name} answer identically for a PM ID and a nonexistent ID without mutating the PM" do
      if name == "discourse_get_post_revision"
        SiteSetting.editing_grace_period = 0
        PostRevisor.new(message).revise!(admin, raw: "Revised #{message.raw}")
        expect(serialized(tool(name, post_id: message.id))).to include(canary)
      end
      private_id = key == :topic_id ? message.topic_id : message.id
      model = key == :topic_id ? Topic : Post
      missing_id = model.unscoped.maximum(:id) + 10_000
      original_post = message.reload.attributes
      original_topic = message.topic.reload.attributes
      post_count = Post.unscoped.where(topic_id: message.topic_id).count
      restrict_messages
      expect(DiscourseMcp.registry.find(:tool, name).content).to be_a(Hash)
      private_response = tool(name, arguments.merge(key => private_id))
      missing_response = tool(name, arguments.merge(key => missing_id))

      expect(private_response).to eq(missing_response)
      expect_no_private_content(private_response)
      if DiscourseMcp.primitive_usable?(DiscourseMcp.registry.find(:tool, name))
        expect(private_response.http_status).to be < 500
        expect(
          private_response.body.dig(:result, :isError) || private_response.body[:error],
        ).to be_present
      else
        expect_blocked(private_response)
      end
      expect(message.reload.attributes).to eq(original_post)
      expect(message.topic.reload.attributes).to eq(original_topic)
      expect(Post.unscoped.where(topic_id: message.topic_id).count).to eq(post_count)
    end
  end

  include_examples "a PM identifier oracle", "discourse_read_topic", :topic_id, {}
  include_examples "a PM identifier oracle", "discourse_read_post", :post_id, {}
  include_examples "a PM identifier oracle",
                   "discourse_read_topic_posts",
                   :topic_id,
                   { selection_mode: "latest" }
  include_examples "a PM identifier oracle",
                   "discourse_get_post_replies",
                   :post_id,
                   { mode: "reply_ids" }
  include_examples "a PM identifier oracle", "discourse_get_topic_view_stats", :topic_id, {}
  include_examples "a PM identifier oracle", "discourse_get_post_revision", :post_id, {}
  include_examples "a PM identifier oracle",
                   "discourse_create_post",
                   :topic_id,
                   { raw: "An attempted reply long enough to be valid." }
  include_examples "a PM identifier oracle",
                   "discourse_update_post",
                   :post_id,
                   { raw: "An attempted edit long enough to be valid." }
  include_examples "a PM identifier oracle",
                   "discourse_update_topic",
                   :topic_id,
                   { title: "An attempted subject change" }
  include_examples "a PM identifier oracle",
                   "discourse_post_set_deleted",
                   :post_id,
                   { deleted: true }
  include_examples "a PM identifier oracle",
                   "discourse_set_topic_closed",
                   :topic_id,
                   { closed: true }
  include_examples "a PM identifier oracle",
                   "discourse_set_topic_pin",
                   :topic_id,
                   { mode: "global" }

  shared_examples "a PM resource oracle" do |kind|
    it "[cr-u1] makes discourse.#{kind} resource responses identical for PM and nonexistent IDs" do
      id = kind == "topic" ? message.topic_id : message.id
      model = kind == "topic" ? Topic : Post
      missing_id = model.unscoped.maximum(:id) + 10_000
      expose(:resource_template, "discourse.#{kind}")
      restrict_messages
      private_response = rpc("resources/read", uri: "discourse://#{kind}/#{id}")
      missing_response = rpc("resources/read", uri: "discourse://#{kind}/#{missing_id}")
      expect(private_response).to eq(missing_response)
      expect(private_response.http_status).to be < 500
      expect_no_private_content(private_response)
    end
  end

  include_examples "a PM resource oracle", "topic"
  include_examples "a PM resource oracle", "post"

  it "[cr-u1] makes the draft-reply prompt answer identically for PM and nonexistent topics" do
    expose(:prompt, "discourse.draft_reply")
    id = message.topic_id
    missing_id = Topic.unscoped.maximum(:id) + 10_000
    restrict_messages
    private_response =
      rpc("prompts/get", name: "discourse.draft_reply", arguments: { topic_id: id })
    missing_response =
      rpc("prompts/get", name: "discourse.draft_reply", arguments: { topic_id: missing_id })
    expect(private_response).to eq(missing_response)
    expect(private_response.http_status).to be < 500
    expect_no_private_content(private_response)
  end

  it "[cr-u1] filters PM search hits and explicit topic filters while preserving public results if usable" do
    SearchIndexer.enable
    public_post = Fabricate(:post, raw: "Public searchable evidence #{SecureRandom.hex(10)}")
    [message, public_post].each { |post| SearchIndexer.index(post, force: true) }
    query = "in:messages orchardwitness"
    # Prove the fixtures are actually searchable by this fully scoped administrator.
    %w[discourse_search discourse_search_posts].each do |name|
      response = tool(name, query:)
      expect(serialized(response)).to include(canary)
    end
    restrict_messages
    %w[discourse_search discourse_search_posts].each do |name|
      registered = expose(:tool, name)
      expect_safe_or_blocked(tool(name, query:), registered) do |result|
        rows = result[:results] || result[:posts]
        expect(rows).to eq([])
        expect(result.fetch(:topics)).to eq([]) if result.key?(:topics)
        expect(result.fetch(:users)).to eq([]) if result.key?(:users)
      end
    end
    name = "discourse_filter_topics"
    registered = expose(:tool, name)
    expect_safe_or_blocked(
      tool(name, filter: "topic:#{message.topic_id},#{public_post.topic_id}"),
      registered,
    ) { |result| expect(result.fetch(:results).pluck(:id)).to eq([public_post.topic_id]) }
  ensure
    SearchIndexer.disable
  end

  it "[cr-u1] removes PM notifications group summaries and reviewable mentions before the page limit" do
    SiteSetting.enable_mentions = true
    public_notification = Fabricate(:notification, user: admin)
    reviewable = Fabricate(:reviewable_flagged_post, topic: message.topic, target: message)
    Fabricate(:private_message_notification, user: admin, topic: message.topic)
    group = Fabricate(:group, name: "secret#{SecureRandom.hex(6)}")
    Fabricate(
      :notification,
      user: admin,
      topic: nil,
      notification_type: Notification.types[:group_message_summary],
      data: {
        group_id: group.id,
        group_name: group.name,
        inbox_count: 1,
        topic_title: message.topic.title,
      }.to_json,
    )
    ReviewableNote.create!(reviewable:, user: recipient, content: "@#{admin.username} #{canary}")
    restrict_messages
    name = "discourse_notification_list"
    registered = expose(:tool, name)
    response = tool(name, limit: 1)
    expect_safe_or_blocked(response, registered) do |result|
      expect(result.fetch(:notifications).pluck(:id)).to eq([public_notification.id])
    end
    expect(serialized(response)).not_to include(group.name)
  end

  it "[cr-u1] removes live and deleted PM topic and post bookmarks before the page limit" do
    public_bookmark = Fabricate(:bookmark, user: admin, updated_at: 5.minutes.ago)
    [message.topic, message].each do |bookmarkable|
      Fabricate(
        :bookmark,
        user: admin,
        bookmarkable:,
        name: "Bookmark #{canary}",
        updated_at: 1.minute.ago,
      )
    end
    restrict_messages
    name = "discourse_bookmark_list"
    registered = expose(:tool, name)
    [false, true].each do |deleted|
      message.topic.trash! if deleted
      expect_safe_or_blocked(tool(name, limit: 1), registered) do |result|
        expect(result.fetch(:bookmarks).pluck(:id)).to eq([public_bookmark.id])
      end
    end
  end

  it "[cr-u1] reads PM reply compose and disguised stored drafts exactly as absent including deleted topics" do
    keys = [
      "topic_#{message.topic_id}",
      Draft::NEW_PRIVATE_MESSAGE,
      "#{Draft::NEW_PRIVATE_MESSAGE}_#{SecureRandom.hex(6)}",
      Draft::NEW_TOPIC,
    ]
    name = "discourse_get_draft"
    registered = expose(:tool, name)
    restrict_messages
    keys.each do |draft_key|
      absent = tool(name, draft_key:)
      data = { title: message.topic.title, reply: message.raw, action: "privateMessage" }.to_json
      Draft.set(admin, draft_key, 0, data)
      present = tool(name, draft_key:)
      expect(present).to eq(absent)
      expect_no_private_content(present)
      if DiscourseMcp.primitive_usable?(registered)
        expect(present.body.dig(:result, :structuredContent)).to eq(draft_key:, found: false)
      else
        expect_blocked(present)
      end
    end
    message.topic.trash!
    present = tool(name, draft_key: keys.first)
    Draft.where(user_id: admin.id, draft_key: keys.first).delete_all
    expect(present).to eq(tool(name, draft_key: keys.first))
    expect_no_private_content(present)
  end

  it "[cr-u1] makes PM draft writes answer like missing topics and preserves the stored private draft" do
    draft_key = "topic_#{message.topic_id}"
    missing_key = "topic_#{Topic.unscoped.maximum(:id) + 10_000}"
    Draft.set(admin, draft_key, 0, { reply: message.raw, action: "reply" }.to_json)
    draft = Draft.find_by!(user_id: admin.id, draft_key:)
    original = draft.attributes
    restrict_messages
    {
      "discourse_save_draft" => {
        sequence: 0,
        reply: "An attempted draft edit long enough to be valid.",
      },
      "discourse_delete_draft" => {
        sequence: 0,
      },
    }.each do |name, arguments|
      response = tool(name, arguments.merge(draft_key:))
      expect(response).to eq(tool(name, arguments.merge(draft_key: missing_key)))
      expect(response.http_status).to be < 500
      expect_no_private_content(response)
      expect(draft.reload.attributes).to eq(original)
    end
  end

  it "[cr-u1] hides PM reviewables and queue counts and matches nonexistent reviewable reads and actions" do
    public_reviewable = Fabricate(:reviewable_flagged_post)
    private_reviewable = Fabricate(:reviewable_flagged_post, topic: message.topic, target: message)
    restrict_messages
    {
      "discourse_get_review_queue_count" => [:count, 1],
      "discourse_list_reviewables" => [:reviewables, [public_reviewable.id]],
      "discourse_list_reviewable_topics" => [:topics, [public_reviewable.topic_id]],
    }.each do |name, (key, expected)|
      registered = expose(:tool, name)
      expect_safe_or_blocked(tool(name), registered) do |result|
        actual = key == :count ? result.fetch(key) : result.fetch(key).pluck(:id)
        expect(actual).to eq(expected)
      end
    end
    missing_id = Reviewable.maximum(:id) + 10_000
    {
      "discourse_get_reviewable" => {
      },
      "discourse_perform_reviewable_action" => {
        action_id: "agree_and_keep",
        confirm: true,
      },
    }.each do |name, arguments|
      private_response = tool(name, arguments.merge(reviewable_id: private_reviewable.id))
      expect(private_response).to eq(tool(name, arguments.merge(reviewable_id: missing_id)))
      expect(private_response.http_status).to be < 500
      expect_no_private_content(private_response)
    end
    expect(private_reviewable.reload).to be_pending
  end

  it "[cr-u1] removes PM user activity even for an administrator reading their own private action types" do
    public_post = Fabricate(:post, user: admin)
    [public_post, message].each do |post|
      UserAction.create!(
        action_type: UserAction::REPLY,
        user: admin,
        acting_user: admin,
        target_topic: post.topic,
        target_post: post,
      )
    end
    UserAction.create!(
      action_type: UserAction::NEW_PRIVATE_MESSAGE,
      user: admin,
      acting_user: admin,
      target_topic: message.topic,
      target_post: message,
    )
    restrict_messages
    {
      "discourse_list_user_posts" => {
      },
      "discourse_list_user_actions" => {
        action_types: %w[replies private_messages_sent private_messages_received],
      },
      "discourse_get_user_summary" => {
      },
      "discourse_list_latest_posts" => {
      },
      "discourse_topic_list" => {
      },
    }.each do |name, arguments|
      registered = expose(:tool, name)
      expect_safe_or_blocked(
        tool(
          name,
          (
            if name == "discourse_list_latest_posts" || name == "discourse_topic_list"
              arguments
            else
              arguments.merge(username: admin.username)
            end
          ),
        ),
        registered,
      ) do |result|
        rows = result[:posts] || result[:actions] || result[:topics] || result[:top_topics]
        expect(rows).to be_an(Array)
        expect(rows.pluck(:topic_id)).not_to include(message.topic_id)
        expect(rows.pluck(:id)).not_to include(message.id) if result[:posts]
        expect(rows.pluck(:id)).not_to include(message.topic_id) if result[:topics]
      end
    end
  end

  it "[cr-u1] suppresses private flag conversations attached to otherwise public reviewables" do
    reporter = Fabricate(:user, refresh_auto_groups: true)
    result =
      PostActionCreator.notify_moderators(reporter, Fabricate(:post), "Flag conversation #{canary}")
    reviewable = result.reviewable
    expect(serialized(tool("discourse_get_reviewable", reviewable_id: reviewable.id))).to include(
      canary,
    )
    restrict_messages
    registered = expose(:tool, "discourse_get_reviewable")
    response = tool("discourse_get_reviewable", reviewable_id: reviewable.id)
    expect_safe_or_blocked(response, registered) do |content|
      expect(content.dig(:reviewable, :id)).to eq(reviewable.id)
      expect(content[:reviewable_conversations]).to be_blank
      expect(content[:conversation_posts]).to be_blank
    end
  end

  it "[cr-u1] suppresses arbitrary webhook delivery bodies that may embed private-message content" do
    hook = Fabricate(:web_hook)
    event =
      Fabricate(
        :web_hook_event,
        web_hook: hook,
        payload: { private_body: message.raw }.to_json,
        response_body: "Remote response #{canary}",
      )
    name = "discourse_list_webhook_events"
    arguments = { webhook_id: hook.id, include_content: true, confirm_sensitive_content: true }
    expect(serialized(tool(name, arguments))).to include(canary)
    restrict_messages
    response = tool(name, arguments)
    expect_no_private_content(response)
    expect(response.http_status).to be < 500
    expect(event.reload.payload).to include(message.raw)
  end

  it "[cr-u1] keeps PM reads closed when persisted PM configuration violates its schema" do
    rule = restrict_messages
    rule.update_columns(config: { "unexpected" => SecureRandom.hex(10) })
    response = tool("discourse_read_post", post_id: message.id)
    missing_id = Post.unscoped.maximum(:id) + 10_000
    expect(response).to eq(tool("discourse_read_post", post_id: missing_id))
    expect(response.http_status).to be < 500
    expect_no_private_content(response)
    expect(DiscourseMcp::ContentPolicy.load).to be_active
  end

  it "[cr-u1] denies PM content when a governing plugin rule has invalid config or a failing compiler" do
    DiscourseMcp.registry.register_content_rule_kind(
      "oracle:closed",
      provider: "oracle",
      affected_data_kinds: ["private_messages"],
      config_contract: {
        type: "object",
        required: ["deny"],
        properties: {
          deny: {
            const: true,
          },
        },
        additionalProperties: false,
      },
      compile: ->(_config) { raise "Oracle compiler failed" },
    )
    rule = McpContentRule.create!(rule_kind: "oracle:closed", config: { "deny" => true })
    private_id = message.id
    missing_id = Post.unscoped.maximum(:id) + 10_000
    [{}, { "deny" => true }].each do |config|
      rule.update_columns(config:)
      expect { DiscourseMcp::ContentPolicy.load }.not_to raise_error
      response = tool("discourse_read_post", post_id: private_id)
      expect(response).to eq(tool("discourse_read_post", post_id: missing_id))
      expect(response.http_status).to be < 500
      expect_no_private_content(response)
      expect_blocked(tool("discourse_create_theme"))
    end
  end

  it "[cr-u1] blocks webhook delivery configuration every theme write and site-setting updates as exit paths" do
    restrict_messages
    names = %w[
      discourse_create_webhook
      discourse_update_webhook
      discourse_redeliver_webhook_event
      discourse_update_site_setting
      discourse_set_theme_code
      discourse_create_theme
      discourse_update_theme
      discourse_delete_theme
      discourse_install_theme
      discourse_sync_remote_theme
      discourse_upload_theme_asset
      discourse_update_theme_setting
      discourse_update_theme_translations
    ]
    theme_writes =
      DiscourseMcp
        .registry
        .all(:tool)
        .select do |registered|
          registered.provider == "core" && registered.required_scopes.include?("mcp:themes:write")
        end
    expect(names & theme_writes.map(&:identifier)).to match_array(theme_writes.map(&:identifier))
    names.each do |name|
      aggregate_failures(name) do
        registered = expose(:tool, name)
        expect(DiscourseMcp.primitive_usable?(registered)).to eq(false)
        expect_blocked(tool(name))
      end
    end

    aggregate_failures("content-free webhook ping remains usable") do
      registered = expose(:tool, "discourse_ping_webhook")
      expect(DiscourseMcp.primitive_usable?(registered)).to eq(true)
      hook = Fabricate(:web_hook, active: false)
      response =
        tool(
          registered.identifier,
          webhook_id: hook.id,
          expected_destination_fingerprint: hook.destination_fingerprint,
          confirm_external_request: true,
        )
      expect(response.http_status).to eq(200)
      expect(response.body[:error]).to be_nil
      expect(response.body.dig(:result, :isError)).not_to eq(true)
      expect(response.body.dig(:result, :structuredContent)).to eq(
        webhook_id: hook.id,
        enqueued: true,
        delivery_succeeded: nil,
      )
    end
  end
end
