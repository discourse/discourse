# frozen_string_literal: true

describe "MCP chat notification access" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:other_user, :user)
  fab!(:group)
  fab!(:public_notification) { Fabricate(:notification, user:) }
  fab!(:channel, :category_channel)
  fab!(:root_message) do
    Fabricate(
      :chat_message,
      chat_channel: channel,
      user: other_user,
      message: "Chat thread root message secret",
    )
  end
  fab!(:thread) { Fabricate(:chat_thread, channel:, original_message: root_message) }
  fab!(:thread_reply) { Fabricate(:chat_message, chat_channel: channel, thread:, user: other_user) }

  before do
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    channel.update!(threading_enabled: true)
    Fabricate(
      :user_chat_channel_membership,
      user:,
      chat_channel: channel,
      following: true,
      notification_level: Chat::UserChatChannelMembership::NOTIFICATION_LEVELS[:always],
    )
    thread.add(user, notification_level: Chat::NotificationLevels.all[:watching])
    Jobs::Chat::NotifyWatching.new.execute(chat_message_id: thread_reply.id)
  end

  def authorize(*extra_scopes)
    scopes = %w[mcp:profile:read mcp:content:read] + extra_scopes
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Chat notification scope test client",
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

  def list_notifications(arguments = {})
    McpPrimitive.find_or_create_by!(
      kind: "tool",
      identifier: "discourse_notification_list",
    ) { |primitive| primitive.enabled = true }
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_notification_list",
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

  it "filters watched chat thread notifications before the limit without the chat read scope" do
    authorize

    list_notifications(limit: 1)

    expect(response.status).to eq(200)
    notifications = response.parsed_body.dig("result", "structuredContent", "notifications")
    expect(response.body).not_to include("Chat thread root message secret")
    expect(notifications.pluck("id")).to eq([public_notification.id])
  end

  it "lists watched chat thread notifications when the chat read scope is granted" do
    authorize("chat:read")

    list_notifications(limit: 1)

    expect(response.status).to eq(200)
    notifications = response.parsed_body.dig("result", "structuredContent", "notifications")
    expect(notifications.sole).to include(
      "notification_type" => Notification.types[:chat_watched_thread],
    )
    expect(notifications.sole.dig("data", "description")).to eq("Chat thread root message secret")
  end
end
