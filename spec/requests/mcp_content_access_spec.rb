# frozen_string_literal: true

describe "MCP content access" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:message) { Fabricate(:private_message_post, user:, recipient: Fabricate(:user)) }

  before do
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    SearchIndexer.enable
  end

  after { SearchIndexer.disable }

  def authorize(*extra_scopes)
    scopes = %w[mcp:profile:read mcp:content:read mcp:content:write] + extra_scopes
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Scope test client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user:,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization:)
  end

  def call_mcp(method, params)
    post "/mcp",
         params: { jsonrpc: "2.0", id: 1, method:, params: }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{@token}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
  end

  def call_tool(name, arguments)
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: name) do |primitive|
      primitive.enabled = true
    end
    call_mcp("tools/call", { name:, arguments: })
  end

  def expect_missing_scope(scope)
    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      %(scope="#{scope}"),
    )
    expect(response.body).not_to include(message.raw)
  end

  it "requires the dedicated moderation and site-setting scopes" do
    authorize
    operations = {
      "discourse_get_review_queue_count" => [{}, "mcp:moderation:read"],
      "discourse_list_reviewables" => [{}, "mcp:moderation:read"],
      "discourse_list_reviewable_topics" => [{}, "mcp:moderation:read"],
      "discourse_get_reviewable" => [{ reviewable_id: 1 }, "mcp:moderation:read"],
      "discourse_get_user_moderation_summary" => [
        { username: user.username },
        "mcp:moderation:read",
      ],
      "discourse_get_post_revision" => [{ post_id: 1 }, "mcp:moderation:read"],
      "discourse_perform_reviewable_action" => [
        { reviewable_id: 1, action_id: "reject", confirm: true },
        "mcp:moderation:write",
      ],
      "discourse_list_site_settings" => [{}, "mcp:site-settings:read"],
      "discourse_update_site_setting" => [
        {
          setting: "title",
          operation: "set",
          value: "Not applied",
          expected_current_value: SiteSetting.title,
          confirm_change: true,
        },
        "mcp:site-settings:write",
      ],
    }

    operations.each do |name, (arguments, scope)|
      call_tool(name, arguments)
      aggregate_failures(name) { expect_missing_scope(scope) }
    end

    expect(SiteSetting.title).not_to eq("Not applied")
  end

  it "does not let a moderation scope bypass Guardian" do
    authorize("mcp:moderation:read")

    call_tool("discourse_get_review_queue_count", {})

    expect(response.status).to eq(403)
    expect(response.parsed_body.dig("error", "message")).to eq("Not authorized")
  end

  it "does not let site-setting scopes bypass Guardian" do
    original_title = SiteSetting.title
    authorize("mcp:site-settings:read", "mcp:site-settings:write")

    call_tool("discourse_list_site_settings", {})
    expect(response.status).to eq(403)
    expect(response.parsed_body.dig("error", "message")).to eq("Not authorized")

    call_tool(
      "discourse_update_site_setting",
      {
        setting: "title",
        operation: "set",
        value: "Unauthorized title",
        expected_current_value: original_title,
        confirm_change: true,
      },
    )
    expect(response.status).to eq(403)
    expect(SiteSetting.title).to eq(original_title)
  end

  it "requires private-message read scope for private moderation content" do
    user.update!(moderator: true)
    Group.refresh_automatic_groups_for_user!(user)
    reviewable =
      Fabricate(
        :reviewable_flagged_post,
        topic: message.topic,
        target: message,
        target_created_by: message.user,
      )
    SiteSetting.editing_grace_period = 0
    PostRevisor.new(message).revise!(message.user, raw: "Revised private message")
    authorize("mcp:moderation:read")

    call_tool("discourse_get_review_queue_count", {})
    expect(response.parsed_body.dig("result", "structuredContent", "count")).to eq(0)

    call_tool("discourse_list_reviewables", {})
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "reviewables")).to eq([])

    call_tool("discourse_list_reviewable_topics", {})
    expect(response.parsed_body.dig("result", "structuredContent", "topics")).to eq([])

    call_tool("discourse_get_reviewable", { reviewable_id: reviewable.id })
    expect_missing_scope("mcp:private-messages:read")

    call_tool("discourse_get_post_revision", { post_id: message.id })
    expect_missing_scope("mcp:private-messages:read")
    expect(response.body).not_to include("Revised private message")

    authorize("mcp:moderation:read", "mcp:private-messages:read")
    call_tool("discourse_get_review_queue_count", {})
    expect(response.parsed_body.dig("result", "structuredContent", "count")).to eq(1)
    call_tool("discourse_get_reviewable", { reviewable_id: reviewable.id })
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    call_tool("discourse_get_post_revision", { post_id: message.id })
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
  end

  it "omits private flag conversations without PM read scope while returning the public reviewable" do
    user.update!(moderator: true)
    Group.refresh_automatic_groups_for_user!(user)
    flag_reason = "private flag conversation 猫"
    result =
      PostActionCreator.notify_moderators(
        Fabricate(:user, refresh_auto_groups: true),
        Fabricate(:post),
        flag_reason,
      )
    authorize("mcp:moderation:read")

    call_tool("discourse_get_reviewable", { reviewable_id: result.reviewable.id })

    structured_content = response.parsed_body.dig("result", "structuredContent")
    expect(structured_content.dig("reviewable", "id")).to eq(result.reviewable.id)
    expect(structured_content["reviewable_conversations"]).to be_blank
    expect(structured_content["conversation_posts"]).to be_blank
    expect(response.body).not_to include(flag_reason)

    authorize("mcp:moderation:read", "mcp:private-messages:read")
    call_tool("discourse_get_reviewable", { reviewable_id: result.reviewable.id })

    expect(response.body).to include(flag_reason)
  end

  it "requires private-message write scope for private reviewable actions" do
    user.update!(moderator: true)
    Group.refresh_automatic_groups_for_user!(user)
    reviewable =
      Fabricate(
        :reviewable_flagged_post,
        topic: message.topic,
        target: message,
        target_created_by: message.user,
      )
    authorize("mcp:moderation:write", "mcp:private-messages:read")

    call_tool(
      "discourse_perform_reviewable_action",
      {
        reviewable_id: reviewable.id,
        action_id: "agree_and_keep",
        expected_version: reviewable.version,
        confirm: true,
      },
    )

    expect_missing_scope("mcp:private-messages:write")
    expect(reviewable.reload).to be_pending
  end

  it "requires the read scope across generic private-message reads" do
    authorize("mcp:private-messages:write")
    operations = {
      "discourse_read_post" => {
        post_id: message.id,
      },
      "discourse_read_topic" => {
        topic_id: message.topic_id,
      },
      "discourse_read_topic_posts" => {
        topic_id: message.topic_id,
        selection_mode: "latest",
      },
      "discourse_get_post_replies" => {
        post_id: message.id,
      },
      "discourse_get_topic_view_stats" => {
        topic_id: message.topic_id,
      },
    }

    operations.each do |name, arguments|
      call_tool(name, arguments)
      aggregate_failures(name) { expect_missing_scope("mcp:private-messages:read") }
    end
  end

  it "requires private-message read scope for private-message drafts" do
    topic = Fabricate(:topic, user:)
    topic_draft_key = "topic_#{topic.id}"
    message_draft_key = "topic_#{message.topic_id}"
    compose_draft_key = "#{Draft::NEW_PRIVATE_MESSAGE}_#{Time.zone.now.to_i}"
    private_reply = "Private reply draft"
    private_title = "Private compose title"
    private_compose = "Private compose draft"
    Draft.set(user, topic_draft_key, 0, { reply: "Public topic draft" }.to_json)
    Draft.set(user, message_draft_key, 0, { reply: private_reply }.to_json)
    Draft.set(user, compose_draft_key, 0, { title: private_title, reply: private_compose }.to_json)
    authorize("mcp:drafts:read")

    call_tool("discourse_get_draft", { draft_key: topic_draft_key })
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "data", "reply")).to eq(
      "Public topic draft",
    )

    {
      message_draft_key => private_reply,
      compose_draft_key => private_compose,
    }.each do |draft_key, reply|
      call_tool("discourse_get_draft", { draft_key: })
      expect_missing_scope("mcp:private-messages:read")
      expect(response.body).not_to include(reply)
    end
    expect(response.body).not_to include(private_title)

    authorize("mcp:drafts:read", "mcp:private-messages:read")
    call_tool("discourse_get_draft", { draft_key: compose_draft_key })
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "data", "reply")).to eq(
      private_compose,
    )
    expect(response.parsed_body.dig("result", "structuredContent", "data", "title")).to eq(
      private_title,
    )
  end

  it "requires the read scope for private-message resources and draft prompts" do
    authorize
    { "topic" => message.topic_id, "post" => message.id }.each do |type, id|
      McpPrimitive.create!(
        kind: "resource_template",
        identifier: "discourse.#{type}",
        enabled: true,
      )
      call_mcp("resources/read", { uri: "discourse://#{type}/#{id}" })
      aggregate_failures(type) { expect_missing_scope("mcp:private-messages:read") }
    end
    McpPrimitive.create!(kind: "prompt", identifier: "discourse.draft_reply", enabled: true)
    call_mcp(
      "prompts/get",
      { name: "discourse.draft_reply", arguments: { topic_id: message.topic_id } },
    )
    expect_missing_scope("mcp:private-messages:read")
  end

  it "requires the write scope before modifying private messages" do
    authorize("mcp:private-messages:read")
    reply = Fabricate(:post, topic: message.topic, user:)
    recoverable_reply = Fabricate(:post, topic: message.topic, user:, user_deleted: true)
    original_raw = message.raw
    original_title = message.topic.title
    operations = {
      "discourse_create_post" => {
        topic_id: message.topic_id,
        raw: "A reply requiring message access",
      },
      "discourse_update_post" => {
        post_id: message.id,
        raw: "An edit requiring message access",
      },
      "discourse_update_topic" => {
        topic_id: message.topic_id,
        title: "A changed private topic title",
      },
      "discourse_post_set_deleted" => {
        post_id: reply.id,
        deleted: true,
      },
    }
    operations.each do |name, arguments|
      call_tool(name, arguments)
      aggregate_failures(name) { expect_missing_scope("mcp:private-messages:write") }
    end
    call_tool("discourse_post_set_deleted", { post_id: recoverable_reply.id, deleted: false })
    expect_missing_scope("mcp:private-messages:write")
    expect(reply.reload.user_deleted).to eq(false)
    expect(recoverable_reply.reload.user_deleted).to eq(true)
    expect(message.reload.raw).to eq(original_raw)
    expect(message.deleted_at).to be_nil
    expect(message.topic.reload.title).to eq(original_title)
    expect(message.topic.posts.count).to eq(3)

    authorize("mcp:private-messages:read", "mcp:private-messages:write")
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(false)
    end
    expect(message.reload.raw).to eq(operations.fetch("discourse_update_post").fetch(:raw))
    expect(message.topic.reload.title).to eq(
      operations.fetch("discourse_update_topic").fetch(:title),
    )
    expect(reply.reload.user_deleted).to eq(true)
    call_tool("discourse_post_set_deleted", { post_id: reply.id, deleted: false })
    expect(response.status).to eq(200)
    expect(reply.reload.user_deleted).to eq(false)
  end

  it "excludes private search matches without revealing whether they exist" do
    authorize
    SearchIndexer.index(message, force: true)
    public_post = Fabricate(:post, raw: "A public secret conversation")
    SearchIndexer.index(public_post, force: true)

    %w[discourse_search discourse_search_posts].each do |name|
      [
        "in:messages",
        "topic:#{message.topic_id}",
        "personal_messages:#{user.username}",
      ].each do |filter|
        %w[secret nonexistentkeywordxyz].each do |term|
          call_tool(name, { query: "#{filter} #{term}" })
          expect(response.status).to eq(200)
          result = response.parsed_body.fetch("result").fetch("structuredContent")
          expect(result.fetch(name == "discourse_search" ? "results" : "posts")).to eq([])
          expect(result.fetch("meta").fetch("has_more")).to eq(false)
        end
      end
      call_tool(name, { query: "in:all secret" })
      expect(response.status).to eq(200)
      result = response.parsed_body.fetch("result").fetch("structuredContent")
      rows = result.fetch(name == "discourse_search" ? "results" : "posts")
      expect(rows.pluck("id")).to eq(
        [name == "discourse_search" ? public_post.topic_id : public_post.id],
      )
    end
  end

  it "excludes private-message activity before pagination unless the read scope is granted" do
    public_post = Fabricate(:post, user:, raw: "A public activity entry")
    private_reply = Fabricate(:post, topic: message.topic, user:, raw: "Private activity reply")
    received_message = Fabricate(:private_message_post, recipient: user)
    [
      [UserAction::REPLY, public_post],
      [UserAction::NEW_PRIVATE_MESSAGE, message],
      [UserAction::REPLY, private_reply],
      [UserAction::GOT_PRIVATE_MESSAGE, received_message],
    ].each do |action_type, target_post|
      UserAction.create!(
        action_type:,
        user:,
        acting_user: user,
        target_topic: target_post.topic,
        target_post:,
      )
    end
    authorize
    %w[private_messages_sent private_messages_received].each do |action_type|
      call_tool(
        "discourse_list_user_actions",
        { username: user.username, action_types: [action_type] },
      )
      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "structuredContent", "actions")).to eq([])
    end
    arguments = {
      username: user.username,
      action_types: %w[replies private_messages_sent private_messages_received],
      limit: 1,
    }
    call_tool("discourse_list_user_actions", arguments)
    result = response.parsed_body.fetch("result").fetch("structuredContent")
    expect(result.fetch("actions").pluck("post_id")).to eq([public_post.id])
    expect(result.fetch("meta")).to include(
      "returned" => 1,
      "has_more" => false,
      "next_offset" => nil,
    )

    authorize("mcp:private-messages:read")
    call_tool("discourse_list_user_actions", arguments.merge(limit: 10))
    actions = response.parsed_body.dig("result", "structuredContent", "actions")
    expect(actions.pluck("post_id")).to contain_exactly(
      public_post.id,
      message.id,
      private_reply.id,
      received_message.id,
    )
  end

  it "preserves content access and allows private-message access only with its scopes" do
    public_post = Fabricate(:post, user:)
    unrelated_message = Fabricate(:private_message_post)
    authorize
    call_tool("discourse_read_post", { post_id: public_post.id })
    expect(response.parsed_body.dig("result", "structuredContent", "raw")).to eq(public_post.raw)
    call_tool(
      "discourse_update_post",
      { post_id: public_post.id, raw: "Updated public content through MCP" },
    )
    expect(public_post.reload.raw).to eq("Updated public content through MCP")

    authorize("mcp:private-messages:read", "mcp:private-messages:write")
    call_tool("discourse_read_post", { post_id: message.id })
    expect(response.parsed_body.dig("result", "structuredContent", "raw")).to eq(message.raw)
    call_tool(
      "discourse_update_post",
      { post_id: message.id, raw: "Updated private content through MCP 猫" },
    )
    expect(message.reload.raw).to eq("Updated private content through MCP 猫")
    SearchIndexer.index(message, force: true)
    call_tool("discourse_search_posts", { query: "in:messages private" })
    expect(response.parsed_body.dig("result", "structuredContent", "posts").pluck("id")).to eq(
      [message.id],
    )
    call_tool("discourse_read_post", { post_id: unrelated_message.id })
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.body).not_to include(unrelated_message.raw)
  end

  it "filters hidden topic posts before pagination while preserving authorized access" do
    authorize
    visible = Fabricate(:post)
    hidden = Fabricate(:post, topic: visible.topic, hidden: true)
    last_visible = Fabricate(:post, topic: visible.topic)
    arguments = { topic_id: visible.topic_id, start_post_number: hidden.post_number, post_limit: 1 }

    expect(user.guardian.can_see?(hidden)).to eq(false)
    call_tool("discourse_read_topic", arguments)
    result = response.parsed_body.fetch("result").fetch("structuredContent")
    expect(result.fetch("posts").pluck("id")).to eq([last_visible.id])
    expect(result.fetch("meta")).to include("returned" => 1, "has_more" => false)

    hidden.update!(user:)
    call_tool("discourse_read_topic", arguments)
    result = response.parsed_body.fetch("result").fetch("structuredContent")
    expect(result.fetch("posts").pluck("id")).to eq([hidden.id])
    expect(result.fetch("meta")).to include("returned" => 1, "has_more" => true)

    hidden.update!(user: visible.user)
    user.update!(moderator: true)
    Group.refresh_automatic_groups_for_user!(user)
    call_tool("discourse_read_topic", arguments)
    expect(response.parsed_body.dig("result", "structuredContent", "posts").pluck("id")).to eq(
      [hidden.id],
    )
  end

  it "filters private-message notifications before the limit unless the read scope is granted" do
    public_notification = Fabricate(:notification, user:)
    other_notification = Fabricate(:notification, user:, topic: nil)
    private_notification = Fabricate(:private_message_notification, user:, topic: message.topic)
    authorize

    call_tool("discourse_notification_list", { limit: 2 })

    expect(response.status).to eq(200)
    notifications = response.parsed_body.dig("result", "structuredContent", "notifications")
    expect(notifications.pluck("id")).to eq([other_notification.id, public_notification.id])

    authorize("mcp:private-messages:read")
    call_tool("discourse_notification_list", { limit: 2 })

    expect(response.status).to eq(200)
    notifications = response.parsed_body.dig("result", "structuredContent", "notifications")
    expect(notifications.pluck("id")).to eq([private_notification.id, other_notification.id])
  end

  it "filters private-message bookmarks before the limit unless the read scope is granted" do
    public_bookmark = Fabricate(:bookmark, user:, updated_at: 3.minutes.ago)
    private_topic_bookmark =
      Fabricate(
        :bookmark,
        user:,
        bookmarkable: message.topic,
        name: "Private topic bookmark note",
        updated_at: 2.minutes.ago,
      )
    private_post_bookmark =
      Fabricate(
        :bookmark,
        user:,
        bookmarkable: message,
        name: "Private post bookmark note",
        updated_at: 1.minute.ago,
      )
    authorize

    call_tool("discourse_bookmark_list", { limit: 2 })

    expect(response.status).to eq(200)
    bookmarks = response.parsed_body.dig("result", "structuredContent", "bookmarks")
    expect(bookmarks.pluck("id")).to eq([public_bookmark.id])
    expect(response.body).not_to include(private_topic_bookmark.name, private_post_bookmark.name)

    authorize("mcp:private-messages:read")
    call_tool("discourse_bookmark_list", { limit: 2 })

    expect(response.status).to eq(200)
    bookmarks = response.parsed_body.dig("result", "structuredContent", "bookmarks")
    expect(bookmarks.pluck("id")).to eq([private_post_bookmark.id, private_topic_bookmark.id])
  end

  it "filters hidden private-message posts when category moderation is enabled" do
    SiteSetting.enable_category_group_moderation = true
    authorize("mcp:private-messages:read")
    Fabricate(
      :post,
      topic: message.topic,
      user: message.topic.allowed_users.where.not(id: user.id).first,
      hidden: true,
    )

    call_tool("discourse_read_topic", { topic_id: message.topic_id })

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "posts").pluck("id")).to eq(
      [message.id],
    )
  end
end
