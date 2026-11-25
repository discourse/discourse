# frozen_string_literal: true

describe DiscourseMcp::Server do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  let(:client) do
    McpOauthClient.create!(
      client_id: SecureRandom.hex,
      name: "Side channel client",
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

  def activate_rule(kind)
    return restrict_messages if kind == "PM-off"

    DiscourseMcp.registry.register_content_data_kind("oracle:metadata", provider: "oracle")
    DiscourseMcp.registry.register_content_rule_kind(
      "oracle:metadata",
      provider: "oracle",
      affected_data_kinds: ["oracle:metadata"],
      config_contract: {
        type: "object",
        additionalProperties: false,
      },
      compile: ->(_config) { DiscourseMcp::ContentPolicy::Evaluator.new },
    )
    McpContentRule.create!(rule_kind: "oracle:metadata", config: {})
    expect(DiscourseMcp::ContentPolicy.load).to be_active
    expect(DiscourseMcp::ContentPolicy.load.denies_all?("private_messages")).to eq(false)
  end

  def tool(name, arguments = {})
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: name).update!(enabled: true)
    expect(DiscourseMcp.registry.find(:tool, name)).to be_present
    request = ActionDispatch::TestRequest.create
    request.headers["MCP-Protocol-Version"] = DiscourseMcp::LEGACY_PROTOCOL_VERSION
    DiscourseMcp::Server.new(
      request:,
      request_context: DiscourseMcp::RequestContext.new(token),
    ).call(
      {
        "jsonrpc" => "2.0",
        "id" => 1,
        "method" => "tools/call",
        "params" => {
          "name" => name,
          "arguments" => arguments.deep_stringify_keys,
        },
      },
    )
  end

  def serialized(response)
    JSON.generate(status: response.http_status, body: response.body, headers: response.headers)
  end

  def content(response)
    expect(response.http_status).to eq(200)
    expect(response.body[:error]).to be_nil
    expect(response.body.dig(:result, :isError)).to eq(false)
    response.body.fetch(:result).fetch(:structuredContent).deep_symbolize_keys
  end

  def expect_blocked(response)
    expect(response.http_status).to eq(200)
    expect(response.body[:error]).to be_nil
    expect(response.body.dig(:result, :isError)).to eq(true)
    expect(response.body.dig(:result, :content)).to eq(
      [{ type: "text", text: I18n.t("mcp.errors.content_policy_blocked") }],
    )
    expect(response.headers.keys.map(&:downcase)).not_to include("www-authenticate")
  end

  describe "tag metadata" do
    let(:private_tag) { Fabricate(:tag) }
    let(:public_tag) { Fabricate(:tag) }
    let(:shared_tag) { Fabricate(:tag) }

    before do
      SiteSetting.tagging_enabled = true
      Fabricate(:topic, tags: [public_tag, shared_tag])
      3.times { Fabricate(:private_message_topic, user: admin, tags: [private_tag, shared_tag]) }
      Tag.update_topic_counts
      expect(private_tag.reload.pm_topic_count).to eq(3)
      expect(shared_tag.reload.pm_topic_count).to eq(3)
    end

    it "omits PM-only tags and PM-derived counts from the entire tag list under PM-off" do
      restrict_messages

      response = tool("discourse_tag_list", limit: 200)
      expected_tags =
        [public_tag, shared_tag].map { |tag| { id: tag.id, name: tag.name, topic_count: 1 } }

      expect(content(response).fetch(:tags)).to match_array(expected_tags)
      text = response.body.fetch(:result).fetch(:content).sole
      expect(JSON.parse(text.fetch(:text), symbolize_names: true).fetch(:tags)).to match_array(
        expected_tags,
      )
      expect(serialized(response)).not_to include(private_tag.name, "pm_topic_count")
    end

    it "preserves the staff tag list and public counts without rule rows" do
      response = tool("discourse_tag_list", limit: 200)

      expect(content(response).fetch(:tags)).to contain_exactly(
        { id: private_tag.id, name: private_tag.name, topic_count: 0 },
        { id: public_tag.id, name: public_tag.name, topic_count: 1 },
        { id: shared_tag.id, name: shared_tag.name, topic_count: 1 },
      )
      expect(serialized(response)).to include(private_tag.name)
    end
  end

  shared_examples "group PM metadata" do |name|
    it "removes PM presence and count fields from #{name} under PM-off" do
      group = Fabricate(:group, has_messages: true)
      Fabricate(:group_private_message_post, user: admin, recipients: group)
      restrict_messages
      arguments =
        (
          if name == "discourse_get_group"
            { id: group.id }
          else
            { group_id: group.id, full_name: "Updated group" }
          end
        )

      response = tool(name, arguments)
      result = content(response).fetch(:group)

      expect(result).to include(id: group.id, name: group.name)
      expect(result.keys).not_to include(:has_messages, :message_count)
      expect(serialized(response)).not_to include("has_messages", "message_count")
      if name == "discourse_update_group"
        expect(group.reload.full_name).to eq(arguments[:full_name])
      end
    end

    it "preserves PM presence and count fields in #{name} without rule rows" do
      group = Fabricate(:group, has_messages: true)
      Fabricate(:group_private_message_post, user: admin, recipients: group)
      arguments =
        (
          if name == "discourse_get_group"
            { id: group.id }
          else
            { group_id: group.id, full_name: "Updated group" }
          end
        )

      result = content(tool(name, arguments)).fetch(:group)

      expect(result).to include(id: group.id, has_messages: true, message_count: 1)
    end
  end

  include_examples "group PM metadata", "discourse_get_group"
  include_examples "group PM metadata", "discourse_update_group"

  shared_examples "restricted request reasons" do |kind|
    it "hides membership request reasons with #{kind} active" do
      request = Fabricate(:group_request)
      activate_rule(kind)

      response = tool("discourse_list_group_membership_requests", name: request.group.name)
      result = content(response)

      expect(result.fetch(:requests).sole).to include(
        user_id: request.user_id,
        username: request.user.username,
      )
      expect(result.fetch(:requests).sole[:reason]).to be_blank
      expect(serialized(response)).not_to include(request.reason)
      expect(request.reload.reason).to be_present
    end
  end

  include_examples "restricted request reasons", "PM-off"
  include_examples "restricted request reasons", "an unrelated rule"

  it "returns membership request reasons without rule rows" do
    request = Fabricate(:group_request)

    response = tool("discourse_list_group_membership_requests", name: request.group.name)

    expect(content(response).fetch(:requests).sole).to include(
      user_id: request.user_id,
      reason: request.reason,
    )
    expect(serialized(response)).to include(request.reason)
  end

  it "refuses membership requests under PM-off without creating a request or PM" do
    group = Fabricate(:group)
    group.add_owner(Fabricate(:user))
    group.update!(allow_membership_requests: true)
    restrict_messages
    response = nil

    expect do
      response =
        tool(
          "discourse_manage_group_membership",
          group_id: group.id,
          action: "request",
          reason: "Please let me join this group",
        )
    end.not_to change {
      [GroupRequest.count, Topic.unscoped.private_messages.count, Post.unscoped.count]
    }

    expect_blocked(response)
    expect(group.users.exists?(id: admin.id)).to eq(false)
  end

  it "creates a membership request and its PM without rule rows" do
    group = Fabricate(:group)
    owner = Fabricate(:user)
    group.add_owner(owner)
    group.update!(allow_membership_requests: true)
    reason = "Please let me join this group"
    response = nil

    expect do
      response =
        tool("discourse_manage_group_membership", group_id: group.id, action: "request", reason:)
    end.to change { GroupRequest.where(group:, user: admin).count }.by(1).and change {
            Topic.private_messages.count
          }.by(1)

    result = content(response)
    expect(result).to include(action: "request", changed: true, member: false)
    expect(GroupRequest.find_by!(group:, user: admin).reason).to eq(reason)
    topic = Topic.private_messages.find(result.fetch(:topic_id))
    expect(topic.first_post.raw).to eq(reason)
    expect(topic.allowed_users.pluck(:id)).to contain_exactly(admin.id, owner.id)
  end

  shared_examples "restricted request handling" do |action|
    it "refuses to #{action} a membership request under PM-off and preserves request and membership" do
      request = Fabricate(:group_request)
      attributes = request.attributes
      restrict_messages
      response = nil

      expect do
        response =
          tool(
            "discourse_handle_group_membership_request",
            group_id: request.group_id,
            username: request.user.username,
            action:,
          )
      end.not_to change { [GroupRequest.count, GroupUser.count, Post.unscoped.count] }

      expect_blocked(response)
      expect(request.reload.attributes).to eq(attributes)
      expect(request.group.users.exists?(id: request.user_id)).to eq(false)
    end
  end

  include_examples "restricted request handling", "approve"
  include_examples "restricted request handling", "deny"

  shared_examples "moderation messages" do |operation|
    it "refuses a custom #{operation} message under PM-off and permits #{operation} without a message" do
      user = Fabricate(:user)
      arguments = {
        username: user.username,
        confirm: true,
        duration_days: 2,
        reason: "Moderation reason",
      }
      restrict_messages
      response = nil

      expect do
        response =
          tool(
            "discourse_#{operation}_user",
            arguments.merge(message: "Custom private explanation"),
          )
      end.not_to change { Post.unscoped.count }

      expect_blocked(response)
      expect(user.reload).not_to be_suspended
      expect(user).not_to be_silenced

      result = content(tool("discourse_#{operation}_user", arguments))
      state = operation == "suspend" ? :suspended : :silenced
      expect(result).to include(operation:, changed: true)
      expect(result.fetch(:user).fetch(state)).to eq(true)
      expect(user.reload.public_send("#{state}?")).to eq(true)
    end

    it "permits #{operation} with a custom message without rule rows" do
      user = Fabricate(:user)
      message = "Custom private explanation for #{user.username}"

      result =
        content(
          tool(
            "discourse_#{operation}_user",
            username: user.username,
            confirm: true,
            duration_days: 2,
            reason: "Moderation reason",
            message:,
          ),
        )

      expect(result).to include(operation:, changed: true)
      expect(user.reload.public_send(operation == "suspend" ? :suspended? : :silenced?)).to eq(true)
      history =
        UserHistory.where(
          target_user_id: user.id,
          action: UserHistory.actions.fetch(:"#{operation}_user"),
        ).sole
      expect(history.details).to include(message)
    end
  end

  include_examples "moderation messages", "suspend"
  include_examples "moderation messages", "silence"

  shared_examples "restricted reviewable actions" do |kind|
    it "refuses reviewable account deletion and delete-and-block with #{kind} active" do
      activate_rule(kind)

      [
        [:suspect_user_reviewable, "delete_user"],
        [:suspect_user_reviewable, "delete_user_block"],
        [:reviewable_queued_post, "delete_user"],
        [:reviewable_queued_post, "delete_user_block"],
      ].each do |fabricator, action_id|
        reviewable = Fabricate(fabricator)
        user = reviewable.is_a?(ReviewableUser) ? reviewable.target : reviewable.target_created_by
        aggregate_failures("#{fabricator}: #{action_id}") do
          response =
            tool(
              "discourse_perform_reviewable_action",
              reviewable_id: reviewable.id,
              action_id:,
              expected_version: reviewable.version,
              confirm: true,
            )

          expect_blocked(response)
          expect(User.exists?(id: user.id)).to eq(true)
          expect(reviewable.reload).to be_pending
        end
      end
    end

    it "refuses nonempty reviewable additional fields with #{kind} active" do
      activate_rule(kind)

      [
        [
          :reviewable_queued_post,
          "revise_and_reject_post",
          { revise_reason: "Custom private feedback" },
        ],
        [:reviewable_queued_post, "reject_post", { revise_reason: "Custom private feedback" }],
        [:suspect_user_reviewable, "approve_user", { send_email: false }],
      ].each do |fabricator, action_id, additional_fields|
        reviewable = Fabricate(fabricator)
        response = nil

        aggregate_failures("#{fabricator}: #{action_id}") do
          expect do
            response =
              tool(
                "discourse_perform_reviewable_action",
                reviewable_id: reviewable.id,
                action_id:,
                confirm: true,
                additional_fields:,
              )
          end.not_to change { Post.unscoped.count }

          expect_blocked(response)
          expect(reviewable.reload).to be_pending
        end
      end
    end

    it "permits ordinary reviewable actions without additional fields with #{kind} active" do
      activate_rule(kind)

      [nil, {}].each do |fields|
        reviewable = Fabricate(:reviewable_queued_post)
        arguments = {
          reviewable_id: reviewable.id,
          action_id: "reject_post",
          expected_version: reviewable.version,
          confirm: true,
        }
        arguments[:additional_fields] = fields unless fields.nil?

        expect(content(tool("discourse_perform_reviewable_action", arguments))).to include(
          success: true,
          reviewable_id: reviewable.id,
        )
        expect(reviewable.reload).to be_rejected
      end
    end
  end

  include_examples "restricted reviewable actions", "PM-off"
  include_examples "restricted reviewable actions", "an unrelated rule"

  it "reports AI theme access restricted rather than successful ready or emergency-blocked under PM-off" do
    plugin = Discourse.plugins_by_name["discourse-ai"]
    skip "discourse-ai is not loaded" if plugin.nil?
    SiteSetting.public_send("#{plugin.enabled_site_setting}=", true)
    %w[discourse_get_theme discourse_create_theme discourse_update_theme].each do |identifier|
      McpPrimitive.find_or_create_by!(kind: "tool", identifier:).update!(enabled: true)
    end
    context = DiscourseAi::Agents::BotContext.new(user: admin, messages: [])
    handoff =
      DiscourseAi::Agents::Tools::ThemeAppHandoff.new(
        {},
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )
    expect(handoff.invoke).to include(status: "ready")
    restrict_messages
    action =
      AiToolAction.create!(
        tool_name: "enable_mcp_theme_access",
        tool_parameters: {
        },
        ai_agent: Fabricate(:ai_agent),
        bot_user_id: Discourse.system_user.id,
      )
    reviewable =
      ReviewableAiToolAction.needs_review!(
        target: action,
        created_by: Discourse.system_user,
        reviewable_by_moderator: true,
      )
    reviewable.add_score(
      Discourse.system_user,
      ReviewableScore.types[:needs_approval],
      force_review: true,
    )
    context.reviewable_id = reviewable.id
    enable =
      DiscourseAi::Agents::Tools::EnableMcpThemeAccess.new(
        {},
        bot_user: Discourse.system_user,
        llm: nil,
        context:,
      )

    enabled_result = enable.invoke
    handoff_result = handoff.invoke

    expect(enabled_result).to include(status: "partial")
    expect(enabled_result.fetch(:message)).to include(
      "#{Discourse.base_url}/admin/config/mcp/content-restrictions",
    )
    expect(handoff_result).to include(status: "needs_setup")
    expect(handoff_result.fetch(:blocked_tools)).to be_present
    expect(handoff_result.fetch(:blocked_tools).join).to include(
      "#{Discourse.base_url}/admin/config/mcp/content-restrictions",
    )
    expect(JSON.generate([enabled_result, handoff_result])).not_to match(/emergency/i)
  end
end
