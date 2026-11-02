# frozen_string_literal: true

describe "Calendar MCP tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:public_event) do
    Fabricate(:event, name: "Public planning meeting", original_starts_at: 1.day.from_now.iso8601)
  end
  fab!(:private_event) do
    Fabricate(
      :event,
      post: Fabricate(:private_message_post, recipient: user),
      name: "Private acquisition meeting",
      original_starts_at: 2.days.from_now.iso8601,
    )
  end

  before do
    SiteSetting.discourse_events_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    McpPrimitive.find_or_create_by!(
      kind: "tool",
      identifier: "discourse_calendar_event_list",
    ) { |primitive| primitive.enabled = true }
  end

  def authorize(*extra_scopes)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Calendar test client",
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

  def call_list_events
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_calendar_event_list",
             arguments: {
             },
           },
         }.to_json,
         headers: {
           "HTTP_AUTHORIZATION" => "Bearer #{@token}",
           "CONTENT_TYPE" => "application/json",
           "HTTP_ACCEPT" => "application/json, text/event-stream",
           "HTTP_MCP_PROTOCOL_VERSION" => DiscourseMcp::LEGACY_PROTOCOL_VERSION,
         }
  end

  it "hides private-message event metadata without the private-message read scope" do
    authorize("discourse-calendar:read")

    call_list_events

    aggregate_failures do
      expect(response.status).to eq(200)
      expect(
        response.parsed_body.dig("result", "structuredContent", "events").pluck("id"),
      ).to contain_exactly(public_event.id)
      expect(response.body).not_to include(private_event.name)
    end

    authorize("discourse-calendar:read", DiscourseMcp::Scopes::PRIVATE_MESSAGES_READ)

    call_list_events

    expect(response.status).to eq(200)
    expect(
      response.parsed_body.dig("result", "structuredContent", "events").pluck("id"),
    ).to contain_exactly(public_event.id, private_event.id)
    expect(response.body).to include(private_event.name)
  end
end
