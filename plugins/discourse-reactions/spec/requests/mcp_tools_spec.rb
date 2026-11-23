# frozen_string_literal: true

describe "Reactions MCP tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:group)
  fab!(:private_post) { Fabricate(:private_message_post, recipient: user) }
  fab!(:public_post, :post)

  before do
    SiteSetting.discourse_reactions_enabled = true
    SiteSetting.discourse_reactions_enabled_reactions = "laughing"
    SiteSetting.mcp_server_enabled = true
    group.add(user)
    McpPrimitive.find_or_create_by!(
      kind: "tool",
      identifier: "discourse_reactions_post_reaction_set",
    ) { |primitive| primitive.enabled = true }
  end

  def authorize(*extra_scopes)
    scopes = [DiscourseMcp::INITIAL_SCOPE, "discourse-reactions:write", *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Reactions test client",
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

  def set_reaction(post)
    post "/mcp",
         params: {
           jsonrpc: "2.0",
           id: 1,
           method: "tools/call",
           params: {
             name: "discourse_reactions_post_reaction_set",
             arguments: {
               post_id: post.id,
               reaction: "laughing",
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

  it "requires the private-message write scope to react to a private message" do
    authorize

    set_reaction(private_post)

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      %(scope="mcp:private-messages:write"),
    )
    expect(
      DiscourseReactions::ReactionManager.reaction_value_for(user:, post: private_post),
    ).to be_nil

    authorize(DiscourseMcp::Scopes::PRIVATE_MESSAGES_WRITE)

    set_reaction(private_post)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "reaction")).to eq("laughing")
    expect(DiscourseReactions::ReactionManager.reaction_value_for(user:, post: private_post)).to eq(
      "laughing",
    )
  end

  it "reacts to public posts with only the reactions scope" do
    authorize

    set_reaction(public_post)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(false)
    expect(DiscourseReactions::ReactionManager.reaction_value_for(user:, post: public_post)).to eq(
      "laughing",
    )
  end
end
