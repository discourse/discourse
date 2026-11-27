# frozen_string_literal: true

describe "Solved MCP tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:private_topic) { Fabricate(:group_private_message_topic, user:, recipient_group: group) }
  fab!(:private_first_post) { Fabricate(:post, topic: private_topic, user:) }
  fab!(:private_reply) { Fabricate(:post, topic: private_topic) }
  fab!(:public_topic) { Fabricate(:topic, user:) }
  fab!(:public_first_post) { Fabricate(:post, topic: public_topic, user:) }
  fab!(:public_reply) { Fabricate(:post, topic: public_topic) }

  before do
    SiteSetting.solved_enabled = true
    SiteSetting.allow_solved_on_all_topics = true
    SiteSetting.allow_solved_in_groups = group.id.to_s
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    McpPrimitive.find_or_create_by!(
      kind: "tool",
      identifier: "discourse_solved_solution_set",
    ) { |primitive| primitive.enabled = true }
  end

  def authorize(*extra_scopes)
    scopes = [DiscourseMcp::INITIAL_SCOPE, "discourse-solved:write", *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Solved test client",
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

  def set_solution(post, accepted:)
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_solved_solution_set",
             arguments: {
               post_id: post.id,
               accepted:,
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

  def accepted?(post)
    DiscourseSolved::TopicAnswer.exists?(answer_post_id: post.id)
  end

  def expect_private_message_scope_required
    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      %(scope="mcp:private-messages:write"),
    )
  end

  it "requires the private-message write scope to change a solution in a personal message" do
    authorize

    set_solution(private_reply, accepted: true)

    expect_private_message_scope_required
    expect(accepted?(private_reply)).to eq(false)

    authorize(DiscourseMcp::Scopes::PRIVATE_MESSAGES_WRITE)
    set_solution(private_reply, accepted: true)

    expect(response.status).to eq(200)
    expect(accepted?(private_reply)).to eq(true)

    authorize
    set_solution(private_reply, accepted: false)

    expect_private_message_scope_required
    expect(accepted?(private_reply)).to eq(true)
  end

  it "changes solutions on public topics with only the Solved scope" do
    authorize

    set_solution(public_reply, accepted: true)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(accepted?(public_reply)).to eq(true)

    set_solution(public_reply, accepted: false)

    expect(response.status).to eq(200)
    expect(accepted?(public_reply)).to eq(false)
  end
end
