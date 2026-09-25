# frozen_string_literal: true

describe "MCP group tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:scope_group, :group)

  before do
    SiteSetting.mcp_server_enabled = true
    scope_group.add(user)
  end

  def authorize(*extra_scopes, auth_user: user)
    scope_group.add(auth_user)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Group tool test client",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: auth_user,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization:)
  end

  def call_tool(name, arguments = {})
    McpPrimitive.find_or_create_by!(kind: "tool", identifier: name) do |primitive|
      primitive.enabled = true
    end
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
         }
  end

  def structured_content
    response.parsed_body.dig("result", "structuredContent")
  end

  def make_owner(group, owner)
    group.add(owner)
    group.group_users.find_by!(user: owner).update!(owner: true)
  end

  it "requires the group read scope" do
    authorize

    {
      "discourse_list_groups" => {
      },
      "discourse_get_group" => {
        id: 1,
      },
      "discourse_list_group_members" => {
        name: "group",
      },
      "discourse_list_group_membership_requests" => {
        name: "group",
      },
      "discourse_list_group_posts" => {
        name: "group",
      },
    }.each do |name, arguments|
      call_tool(name, arguments)
      aggregate_failures(name) do
        expect(response.status).to eq(403)
        expect(response.headers["WWW-Authenticate"]).to include(
          'error="insufficient_scope"',
          'scope="mcp:groups:read"',
        )
      end
    end
  end

  it "lists only groups visible to the user" do
    visible_group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
    make_owner(hidden_group, Fabricate(:user))
    authorize("mcp:groups:read")

    call_tool("discourse_list_groups", { limit: 100 })

    expect(response.status).to eq(200)
    expect(structured_content["groups"].pluck("id")).to include(visible_group.id)
    expect(structured_content["groups"].pluck("id")).not_to include(hidden_group.id)
  end

  it "does not expose member counts when group membership is private" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    group.add(Fabricate(:user))
    authorize("mcp:groups:read")

    call_tool("discourse_list_groups", { limit: 100 })

    group_json = structured_content["groups"].find { |item| item["id"] == group.id }
    expect(group_json["can_see_members"]).to eq(false)
    expect(group_json["user_count"]).to be_nil
  end

  it "does not expose private member counts through group ordering" do
    prefix = "pc#{SecureRandom.hex(3)}"
    small_group =
      Fabricate(
        :group,
        name: "#{prefix}_a",
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    small_group.add(Fabricate(:user))
    large_group =
      Fabricate(
        :group,
        name: "#{prefix}_z",
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    3.times { large_group.add(Fabricate(:user)) }
    authorize("mcp:groups:read")

    call_tool("discourse_list_groups", { filter: prefix, order: "user_count", ascending: false })

    expect(structured_content["groups"].pluck("id")).to eq([small_group.id, large_group.id])
  end

  it "respects the group directory site setting" do
    SiteSetting.enable_group_directory = false
    authorize("mcp:groups:read")

    call_tool("discourse_list_groups")
    expect(response.status).to eq(403)

    moderator = Fabricate(:moderator, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: moderator)
    call_tool("discourse_list_groups")
    expect(response.status).to eq(200)
  end

  it "does not reveal a hidden group when the token has scope but the user lacks access" do
    hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
    make_owner(hidden_group, Fabricate(:user))
    authorize("mcp:groups:read")

    call_tool("discourse_get_group", { id: hidden_group.id })

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.body).not_to include(hidden_group.name)
  end

  it "returns the safe group fields exposed by the existing group API" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        title: "Group title",
        full_name: "Group full name",
        bio_raw: "Group biography",
        membership_request_template: "Tell us why you want to join",
      )
    sign_in(user)
    get "/groups/#{group.name}.json"
    api_group = response.parsed_body.fetch("group")
    authorize("mcp:groups:read")

    call_tool("discourse_get_group", { id: group.id })

    fields = %w[
      primary_group
      grant_trust_level
      flair_url
      flair_bg_color
      flair_color
      bio_cooked
      default_notification_level
      membership_request_template
      publish_read_state
      mentionable
      messageable
    ]
    expect(structured_content.fetch("group").slice(*fields)).to eq(api_group.slice(*fields))
  end

  it "gets an automatic group that the existing group API allows the user to see" do
    automatic_group = Group[:trust_level_0]
    authorize("mcp:groups:read")

    call_tool("discourse_get_group", { id: automatic_group.id })

    expect(response.status).to eq(200)
    expect(structured_content.dig("group", "id")).to eq(automatic_group.id)
  end

  it "does not return group email credentials" do
    secret = "mcp-group-secret-#{SecureRandom.hex}"
    group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    group.update_columns(
      incoming_email: "mcp-#{SecureRandom.hex}@example.com",
      email_username: "mcp-user-#{SecureRandom.hex}",
      email_password: secret,
    )
    admin = Fabricate(:admin, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: admin)

    call_tool("discourse_get_group", { id: group.id })

    expect(response.status).to eq(200)
    expect(response.body).not_to include(secret, group.incoming_email, group.email_username)
  end

  it "does not add membership queries for each listed group" do
    Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    authorize("mcp:groups:read")

    initial_queries =
      track_sql_queries { call_tool("discourse_list_groups", { limit: 100 }) }.grep(/group_users/i)
    5.times { Fabricate(:group, visibility_level: Group.visibility_levels[:public]) }
    expanded_queries =
      track_sql_queries { call_tool("discourse_list_groups", { limit: 100 }) }.grep(/group_users/i)

    expect(expanded_queries.size).to be <= initial_queries.size
  end

  it "applies group directory query modifiers" do
    visible_group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    filtered_group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    plugin = Plugin::Instance.new
    modifier = proc { |groups| groups.where.not(id: filtered_group.id) }
    plugin.register_modifier(:groups_index_query, &modifier)
    authorize("mcp:groups:read")

    call_tool("discourse_list_groups", { limit: 100 })

    expect(structured_content["groups"].pluck("id")).to include(visible_group.id)
    expect(structured_content["groups"].pluck("id")).not_to include(filtered_group.id)
  ensure
    DiscoursePluginRegistry.unregister_modifier(plugin, :groups_index_query, &modifier) if plugin
  end

  it "preserves the difference between moderator and administrator visibility" do
    hidden_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
    make_owner(hidden_group, Fabricate(:user))
    moderator = Fabricate(:moderator, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: moderator)

    call_tool("discourse_get_group", { id: hidden_group.id })
    expect(response.parsed_body.dig("result", "isError")).to eq(true)

    admin = Fabricate(:admin, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: admin)
    call_tool("discourse_get_group", { id: hidden_group.id })

    expect(response.status).to eq(200)
    expect(structured_content.dig("group", "id")).to eq(hidden_group.id)
  end

  it "does not list private members when the token has scope but the user lacks access" do
    public_group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    visible_member = Fabricate(:user)
    public_group.add(visible_member)
    private_group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    private_member = Fabricate(:user)
    private_group.add(private_member)
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_members", { name: public_group.name })
    expect(structured_content["members"].pluck("username")).to include(visible_member.username)

    call_tool("discourse_list_group_members", { name: private_group.name })
    expect(response.status).to eq(403)
    expect(response.body).not_to include(private_member.username)
  end

  it "hides activity timestamps for members whose profiles are hidden" do
    SiteSetting.allow_users_to_hide_profile = true
    public_group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    hidden_member = Fabricate(:user, last_seen_at: 1.hour.ago, last_posted_at: 2.hours.ago)
    hidden_member.user_option.update!(hide_profile: true)
    visible_member = Fabricate(:user, last_seen_at: 3.hours.ago, last_posted_at: 4.hours.ago)
    public_group.add(hidden_member)
    public_group.add(visible_member)
    user.update!(trust_level: TrustLevel[2])
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_members", { name: public_group.name })

    members = structured_content["members"]
    hidden_member_json = members.find { |member| member["id"] == hidden_member.id }
    visible_member_json = members.find { |member| member["id"] == visible_member.id }
    expect(hidden_member_json).not_to include("last_seen_at", "last_posted_at")
    expect(visible_member_json).to include("last_seen_at", "last_posted_at")
  end

  it "uses the existing group API filtering rules for members" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    first_member = Fabricate(:user)
    second_member = Fabricate(:user)
    group.add(first_member)
    group.add(second_member)
    authorize("mcp:groups:read")

    call_tool(
      "discourse_list_group_members",
      { name: group.name, filter: "#{first_member.username},#{second_member.username}" },
    )

    expect(structured_content["members"].pluck("username")).to contain_exactly(
      first_member.username,
      second_member.username,
    )

    call_tool("discourse_list_group_members", { name: group.name, filter: first_member.email })
    expect(structured_content["members"]).to be_empty

    admin = Fabricate(:admin, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: admin)
    call_tool("discourse_list_group_members", { name: group.name, filter: first_member.email })

    expect(structured_content["members"].pluck("username")).to contain_exactly(
      first_member.username,
    )
  end

  it "requires group management permission even when the token has scope" do
    managed_group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    make_owner(managed_group, user)
    managed_group.update!(allow_membership_requests: true)
    requester = Fabricate(:user)
    request = Fabricate(:group_request, group: managed_group, user: requester)
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_membership_requests", { name: managed_group.name })
    expect(structured_content["requests"]).to contain_exactly(
      include("username" => requester.username, "reason" => request.reason),
    )

    unmanaged_group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    make_owner(unmanaged_group, Fabricate(:user))
    unmanaged_group.update!(allow_membership_requests: true)
    hidden_request = Fabricate(:group_request, group: unmanaged_group)
    call_tool("discourse_list_group_membership_requests", { name: unmanaged_group.name })

    expect(response.status).to eq(403)
    expect(response.body).not_to include(hidden_request.reason)
  end

  it "uses the existing group API filtering rules for membership requests" do
    group = Fabricate(:group, visibility_level: Group.visibility_levels[:public])
    make_owner(group, user)
    first_request = Fabricate(:group_request, group:)
    second_request = Fabricate(:group_request, group:)
    authorize("mcp:groups:read")

    call_tool(
      "discourse_list_group_membership_requests",
      {
        name: group.name,
        filter: "#{first_request.user.username},#{second_request.user.username}",
      },
    )

    expect(structured_content["requests"].pluck("username")).to contain_exactly(
      first_request.user.username,
      second_request.user.username,
    )

    admin = Fabricate(:admin, refresh_auto_groups: true)
    authorize("mcp:groups:read", auth_user: admin)
    call_tool(
      "discourse_list_group_membership_requests",
      { name: group.name, filter: first_request.user.email },
    )

    expect(structured_content["requests"].pluck("username")).to contain_exactly(
      first_request.user.username,
    )
  end

  it "lists only group posts visible to the user" do
    author_group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    author = Fabricate(:user)
    author_group.add(author)
    public_post = Fabricate(:post, user: author)
    private_category = Fabricate(:private_category, group: Fabricate(:group))
    private_post =
      Fabricate(:post, user: author, topic: Fabricate(:topic, category: private_category))
    private_message = Fabricate(:private_message_post, user: author)
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_posts", { name: author_group.name })

    expect(structured_content["posts"].pluck("id")).to include(public_post.id)
    expect(structured_content["posts"].pluck("id")).not_to include(private_post.id)
    expect(structured_content["posts"].pluck("id")).not_to include(private_message.id)
  end

  it "rejects multiple group post cursors" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    authorize("mcp:groups:read")

    call_tool(
      "discourse_list_group_posts",
      { name: group.name, before_post_id: 1, before: 1.day.ago.iso8601 },
    )

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.body).to include(I18n.t("mcp.errors.group_post_single_cursor"))
  end

  it "does not list group posts when the token has scope but the user cannot see members" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:owners],
      )
    author = Fabricate(:user)
    group.add(author)
    post = Fabricate(:post, user: author)
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_posts", { name: group.name })

    expect(response.status).to eq(403)
    expect(response.body).not_to include(post.topic.title)
  end
end
