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
    expect(structured_content.dig("group", "id")).to eq(group.id)
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

  it "keeps membership queries bounded for moderators managing owner-visible groups" do
    SiteSetting.moderators_manage_groups = true
    moderator = Fabricate(:moderator, refresh_auto_groups: true)
    group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
    make_owner(group, moderator)
    authorize("mcp:groups:read", auth_user: moderator)

    initial_queries =
      track_sql_queries { call_tool("discourse_list_groups", { limit: 100 }) }.grep(/group_users/i)
    expect(structured_content["groups"]).to include(
      include("id" => group.id, "can_admin_group" => true, "can_edit_group" => true),
    )

    5.times do
      owned_group = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
      make_owner(owned_group, moderator)
    end
    expanded_queries =
      track_sql_queries { call_tool("discourse_list_groups", { limit: 100 }) }.grep(/group_users/i)

    expect(response.status).to eq(200)
    expect(expanded_queries.size).to be <= initial_queries.size
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

  it "paginates group posts when IDs and creation times have different orders" do
    group =
      Fabricate(
        :group,
        visibility_level: Group.visibility_levels[:public],
        members_visibility_level: Group.visibility_levels[:public],
      )
    author = Fabricate(:user)
    group.add(author)
    newest_post = Fabricate(:post, user: author, created_at: 1.day.ago)
    shared_created_at = 2.days.ago
    lower_id_post = Fabricate(:post, user: author, created_at: shared_created_at)
    higher_id_post = Fabricate(:post, user: author, created_at: shared_created_at)
    authorize("mcp:groups:read")

    call_tool("discourse_list_group_posts", { name: group.name, limit: 1 })

    expect(structured_content["posts"].pluck("id")).to eq([newest_post.id])
    expect(structured_content.dig("meta", "has_more")).to eq(true)
    cursor = structured_content.dig("meta", "next_before_post_id")

    call_tool("discourse_list_group_posts", { name: group.name, limit: 1, before_post_id: cursor })

    expect(structured_content["posts"].pluck("id")).to eq([higher_id_post.id])
    expect(structured_content.dig("meta", "has_more")).to eq(true)

    cursor = structured_content.dig("meta", "next_before_post_id")
    call_tool("discourse_list_group_posts", { name: group.name, limit: 1, before_post_id: cursor })

    expect(structured_content["posts"].pluck("id")).to eq([lower_id_post.id])
    expect(structured_content.dig("meta", "has_more")).to eq(false)
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

  describe "write tools" do
    fab!(:group)
    fab!(:member, :user)

    def tool_error
      response.parsed_body.dig("result", "content", 0, "text")
    end

    it "requires the group write scope" do
      authorize("mcp:groups:read")

      {
        "discourse_create_group" => {
          name: "new-group",
        },
        "discourse_update_group" => {
          group_id: group.id,
          bio_raw: "hi",
        },
        "discourse_delete_group" => {
          group_id: group.id,
          expected_name: group.name,
          confirm: true,
        },
        "discourse_manage_group_members" => {
          group_id: group.id,
          action: "add",
          usernames: [member.username],
        },
        "discourse_invite_group_members" => {
          group_id: group.id,
          emails: ["newcomer@example.com"],
        },
        "discourse_manage_group_owners" => {
          group_id: group.id,
          action: "add",
          usernames: [member.username],
        },
        "discourse_manage_group_membership" => {
          group_id: group.id,
          action: "join",
        },
        "discourse_handle_group_membership_request" => {
          group_id: group.id,
          username: member.username,
          action: "approve",
        },
      }.each do |name, arguments|
        call_tool(name, arguments)
        aggregate_failures(name) do
          expect(response.status).to eq(403)
          expect(response.headers["WWW-Authenticate"]).to include(
            'error="insufficient_scope"',
            'scope="mcp:groups:write"',
          )
        end
      end
    end

    it "denies every management tool when the token has scope but the user has no group rights" do
      authorize("mcp:groups:write")

      {
        "discourse_create_group" => {
          name: "new-group",
        },
        "discourse_update_group" => {
          group_id: group.id,
          bio_raw: "hi",
        },
        "discourse_delete_group" => {
          group_id: group.id,
          expected_name: group.name,
          confirm: true,
        },
        "discourse_manage_group_members" => {
          group_id: group.id,
          action: "add",
          usernames: [member.username],
        },
        "discourse_invite_group_members" => {
          group_id: group.id,
          emails: ["newcomer@example.com"],
        },
        "discourse_manage_group_owners" => {
          group_id: group.id,
          action: "add",
          usernames: [member.username],
        },
        "discourse_handle_group_membership_request" => {
          group_id: group.id,
          username: member.username,
          action: "approve",
        },
      }.each do |name, arguments|
        call_tool(name, arguments)
        aggregate_failures(name) { expect(response.status).to eq(403) }
      end

      expect(Group.exists?(group.id)).to eq(true)
      expect(group.reload.users).not_to include(member)
    end

    it "does not reveal groups the user cannot see" do
      hidden = Fabricate(:group, visibility_level: Group.visibility_levels[:owners])
      make_owner(hidden, Fabricate(:user))
      authorize("mcp:groups:write")

      call_tool("discourse_update_group", { group_id: hidden.id, bio_raw: "hi" })

      expect(response.status).to eq(200)
      expect(tool_error).to eq(I18n.t("mcp.errors.group_not_found"))
    end

    describe "discourse_create_group" do
      it "creates a group with owners and members for an admin" do
        admin = Fabricate(:admin, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: admin)

        call_tool(
          "discourse_create_group",
          {
            name: "docs-team",
            full_name: "Documentation 猫",
            visibility_level: Group.visibility_levels[:logged_on_users],
            owner_usernames: [member.username],
          },
        )

        expect(response.status).to eq(200)
        created = Group.find(structured_content["id"])
        expect(created.name).to eq("docs-team")
        expect(created.full_name).to eq("Documentation 猫")
        expect(created.visibility_level).to eq(Group.visibility_levels[:logged_on_users])
        expect(created.group_users.find_by(user: member).owner).to eq(true)
      end

      it "creates a group with a unicode name when unicode usernames are enabled" do
        SiteSetting.unicode_usernames = true
        admin = Fabricate(:admin, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: admin)

        call_tool("discourse_create_group", { name: "docs-猫" })

        expect(response.status).to eq(200)
        expect(Group.find(structured_content["id"]).name).to eq("docs-猫")
      end

      it "lets a moderator create a group only when moderators manage groups" do
        moderator = Fabricate(:moderator, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: moderator)

        call_tool("discourse_create_group", { name: "mod-group" })
        expect(response.status).to eq(403)

        SiteSetting.moderators_manage_groups = true
        call_tool("discourse_create_group", { name: "mod-group" })
        expect(response.status).to eq(200)
      end

      it "reports validation errors without creating a group" do
        admin = Fabricate(:admin, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: admin)

        expect { call_tool("discourse_create_group", { name: group.name }) }.not_to change {
          Group.count
        }
        expect(response.parsed_body.dig("result", "isError")).to eq(true)
      end

      it "rejects fields the tool does not expose" do
        admin = Fabricate(:admin, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: admin)

        call_tool("discourse_create_group", { name: "smtp-group", smtp_server: "evil.example.com" })

        expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
      end
    end

    describe "discourse_update_group" do
      it "applies only existing categories to group and member notification defaults" do
        category = Fabricate(:category)
        missing_id = Category.maximum(:id) + 1
        make_owner(group, user)
        authorize("mcp:groups:write")

        call_tool(
          "discourse_update_group",
          {
            group_id: group.id,
            watching_category_ids: [category.id, missing_id],
            update_existing_users: true,
          },
        )

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("result", "isError")).to eq(false)
        expect(group.reload.group_category_notification_defaults.pluck(:category_id)).to eq(
          [category.id],
        )
        expect(CategoryUser.where(user:).pluck(:category_id, :notification_level)).to eq(
          [[category.id, NotificationLevels.all[:watching]]],
        )
      end

      it "rejects conflicting tag levels including synonyms before changing the group or its members" do
        tag = Fabricate(:tag)
        synonym = Fabricate(:tag, target_tag: tag)
        make_owner(group, user)
        group.update!(watching_tags: [tag.name])
        original_bio = group.bio_raw
        TagUser.change(user.id, tag.id, NotificationLevels.all[:watching])
        authorize("mcp:groups:write")

        [tag.name, synonym.name.upcase].each do |name|
          call_tool(
            "discourse_update_group",
            {
              group_id: group.id,
              bio_raw: "Must not be saved",
              watching_tags: [tag.name],
              tracking_tags: [name],
              update_existing_users: true,
            },
          )

          expect(response.parsed_body.dig("result", "isError")).to eq(true)
          expect(tool_error).to eq(I18n.t("groups.errors.conflicting_notification_defaults"))
          expect(group.reload.bio_raw).to eq(original_bio)
          expect(group.group_tag_notification_defaults.pluck(:tag_id, :notification_level)).to eq(
            [[tag.id, NotificationLevels.all[:watching]]],
          )
          expect(TagUser.find_by!(user:, tag:).notification_level).to eq(
            NotificationLevels.all[:watching],
          )
        end
      end

      it "rejects conflicting category levels even when existing members would be left alone" do
        category = Fabricate(:category)
        make_owner(group, user)
        authorize("mcp:groups:write")

        call_tool(
          "discourse_update_group",
          {
            group_id: group.id,
            watching_category_ids: [category.id],
            muted_category_ids: [category.id],
            update_existing_users: false,
          },
        )

        expect(response.parsed_body.dig("result", "isError")).to eq(true)
        expect(tool_error).to eq(I18n.t("groups.errors.conflicting_notification_defaults"))
        expect(group.reload.group_category_notification_defaults).to be_empty
        expect(CategoryUser.where(user:, category:)).to be_empty
      end

      it "moves a tag default and matching member preferences with a partial update" do
        tag = Fabricate(:tag)
        make_owner(group, user)
        group.update!(tracking_tags: [tag.name])
        TagUser.change(user.id, tag.id, NotificationLevels.all[:tracking])
        group.add(member)
        TagUser.change(member.id, tag.id, NotificationLevels.all[:muted])
        authorize("mcp:groups:write")

        call_tool(
          "discourse_update_group",
          { group_id: group.id, watching_tags: [tag.name], update_existing_users: true },
        )

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
        expect(
          group.reload.group_tag_notification_defaults.pluck(:tag_id, :notification_level),
        ).to eq([[tag.id, NotificationLevels.all[:watching]]])
        expect(TagUser.find_by!(user:, tag:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
        expect(TagUser.find_by!(user: member, tag:).notification_level).to eq(
          NotificationLevels.all[:muted],
        )
        newcomer = Fabricate(:user)
        group.add(newcomer)
        expect(TagUser.find_by!(user: newcomer, tag:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
      end

      it "applies mixed-case tag names and synonyms to the canonical tags for members" do
        tag = Fabricate(:tag, name: "release-猫")
        target = Fabricate(:tag)
        synonym = Fabricate(:tag, target_tag: target)
        make_owner(group, user)
        authorize("mcp:groups:write")

        call_tool(
          "discourse_update_group",
          {
            group_id: group.id,
            watching_tags: [tag.name.upcase, synonym.name, target.name],
            update_existing_users: true,
          },
        )

        expect(response.status).to eq(200)
        expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
        expect(group.reload.group_tag_notification_defaults.pluck(:tag_id)).to contain_exactly(
          tag.id,
          target.id,
        )
        expect(TagUser.where(user:).pluck(:tag_id, :notification_level)).to contain_exactly(
          [tag.id, NotificationLevels.all[:watching]],
          [target.id, NotificationLevels.all[:watching]],
        )
      end

      it "preserves omitted notification defaults when editing the profile" do
        category = Fabricate(:category)
        tag = Fabricate(:tag)
        make_owner(group, user)
        group.update!(watching_category_ids: [category.id], tracking_tags: [tag.name])
        group.add(member)
        CategoryUser.set_notification_level_for_category(
          member,
          NotificationLevels.all[:watching],
          category.id,
        )
        TagUser.change(member.id, tag.id, NotificationLevels.all[:tracking])
        authorize("mcp:groups:write")

        [nil, true].each do |choice|
          arguments = { group_id: group.id, bio_raw: "Updated bio 猫" }
          arguments[:update_existing_users] = choice unless choice.nil?
          call_tool("discourse_update_group", arguments)

          expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
          expect(CategoryUser.find_by(user: member, category:)&.notification_level).to eq(
            NotificationLevels.all[:watching],
          )
          expect(TagUser.find_by(user: member, tag:)&.notification_level).to eq(
            NotificationLevels.all[:tracking],
          )
        end
        expect(group.reload.bio_raw).to eq("Updated bio 猫")
      end

      it "lets a group owner change the profile but ignores staff-only fields" do
        make_owner(group, user)
        original_name = group.name
        authorize("mcp:groups:write")

        call_tool(
          "discourse_update_group",
          { group_id: group.id, bio_raw: "We write docs 猫", name: "renamed" },
        )

        expect(response.status).to eq(200)
        group.reload
        expect(group.bio_raw).to eq("We write docs 猫")
        expect(group.name).to eq(original_name)
      end

      it "requires at least one field the user may change" do
        make_owner(group, user)
        authorize("mcp:groups:write")

        call_tool("discourse_update_group", { group_id: group.id, name: "renamed" })

        expect(tool_error).to eq(I18n.t("mcp.errors.group_update_required"))
      end

      it "asks for confirmation before changing notification defaults of existing members" do
        admin = Fabricate(:admin, refresh_auto_groups: true)
        category = Fabricate(:category)
        group.add(member)
        authorize("mcp:groups:write", auth_user: admin)

        call_tool(
          "discourse_update_group",
          { group_id: group.id, watching_category_ids: [category.id] },
        )

        expect(response.parsed_body.dig("result", "isError")).to eq(true)
        expect(tool_error).to eq(
          I18n.t("mcp.errors.group_update_existing_users_required", count: 1),
        )
        expect(CategoryUser.where(user: member, category:)).to be_empty

        call_tool(
          "discourse_update_group",
          { group_id: group.id, watching_category_ids: [category.id], update_existing_users: true },
        )

        expect(response.status).to eq(200)
        expect(CategoryUser.find_by(user: member, category:).notification_level).to eq(
          NotificationLevels.all[:watching],
        )
      end
    end

    describe "discourse_delete_group" do
      fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }

      it "deletes a group for an admin after confirmation" do
        authorize("mcp:groups:write", auth_user: admin)

        call_tool(
          "discourse_delete_group",
          { group_id: group.id, expected_name: group.name, confirm: true },
        )

        expect(response.status).to eq(200)
        expect(structured_content).to eq("deleted" => true, "group_id" => group.id)
        expect(Group.exists?(group.id)).to eq(false)
      end

      it "refuses without confirmation or with the wrong name" do
        authorize("mcp:groups:write", auth_user: admin)

        call_tool(
          "discourse_delete_group",
          { group_id: group.id, expected_name: group.name, confirm: false },
        )
        expect(tool_error).to eq(I18n.t("mcp.errors.group_delete_confirmation_required"))

        call_tool(
          "discourse_delete_group",
          { group_id: group.id, expected_name: "wrong", confirm: true },
        )
        expect(tool_error).to eq(I18n.t("mcp.errors.group_delete_name_mismatch"))
        expect(Group.exists?(group.id)).to eq(true)
      end

      it "refuses an automatic group" do
        authorize("mcp:groups:write", auth_user: admin)
        automatic = Group.find(Group::AUTO_GROUPS[:trust_level_1])

        call_tool(
          "discourse_delete_group",
          { group_id: automatic.id, expected_name: automatic.name, confirm: true },
        )

        expect(tool_error).to eq(I18n.t("groups.errors.can_not_modify_automatic"))
        expect(Group.exists?(automatic.id)).to eq(true)
      end

      it "refuses a moderator who may otherwise manage groups" do
        SiteSetting.moderators_manage_groups = true
        moderator = Fabricate(:moderator, refresh_auto_groups: true)
        make_owner(group, moderator)
        authorize("mcp:groups:write", auth_user: moderator)

        call_tool(
          "discourse_delete_group",
          { group_id: group.id, expected_name: group.name, confirm: true },
        )

        expect(response.status).to eq(403)
        expect(Group.exists?(group.id)).to eq(true)
      end
    end

    describe "discourse_manage_group_members" do
      before { make_owner(group, user) }

      it "rejects conflicting selectors without changing members or owners" do
        authorize("mcp:groups:write")
        %w[discourse_manage_group_members discourse_manage_group_owners].each do |tool|
          expect do
            call_tool(
              tool,
              {
                group_id: group.id,
                action: "add",
                usernames: [member.username],
                user_ids: [user.id],
              },
            )
          end.not_to change { group.group_users.count }

          expect(response.parsed_body.dig("result", "isError")).to eq(true)
          expect(tool_error).to eq(I18n.t("mcp.errors.group_member_selector_required"))
        end
      end

      it "resolves mixed-case account emails for a user who may view emails" do
        authorize("mcp:groups:write", auth_user: Fabricate(:admin, refresh_auto_groups: true))
        call_tool(
          "discourse_manage_group_members",
          { group_id: group.id, action: "add", user_emails: [member.email.upcase] },
        )

        expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
        expect(group.users).to include(member)
      end

      it "refuses the email selector for an owner who may not view emails" do
        authorize("mcp:groups:write")
        expect(user.guardian.can_see_emails?).to eq(false)

        %w[discourse_manage_group_members discourse_manage_group_owners].each do |tool|
          [member.email, "missing@example.com"].each do |email|
            call_tool(tool, { group_id: group.id, action: "add", user_emails: [email] })
            expect(response.status).to eq(403)
            expect(response.body).not_to include(email, member.username)
          end
        end
        expect(group.reload.users).not_to include(member)
      end

      it "rejects more than 100 parsed usernames before changing members or owners" do
        selected_users = 101.times.map { |index| Fabricate(:user, username: "limituser#{index}") }
        usernames = selected_users.map(&:username).each_slice(2).map { |names| names.join(",") }
        authorize("mcp:groups:write")

        %w[discourse_manage_group_members discourse_manage_group_owners].each do |tool|
          expect do
            call_tool(tool, { group_id: group.id, action: "add", usernames: })
          end.not_to change { group.group_users.count }

          expect(response.parsed_body.dig("result", "isError")).to eq(true)
          expect(tool_error).to eq(I18n.t("mcp.errors.group_user_limit", count: 100))
        end
      end

      it "accepts exactly 100 parsed usernames for member and owner changes" do
        selected_users = 100.times.map { |index| Fabricate(:user, username: "limituser#{index}") }
        usernames = selected_users.map(&:username).each_slice(2).map { |names| names.join(",") }
        authorize("mcp:groups:write")

        %w[discourse_manage_group_members discourse_manage_group_owners].each do |tool|
          call_tool(tool, { group_id: group.id, action: "add", usernames: })

          expect(response.parsed_body.dig("result", "isError")).to eq(false)
          expect(structured_content["usernames"]).to match_array(selected_users.map(&:username))
        end
        expect(group.group_users.where(owner: true).pluck(:user_id)).to match_array(
          [user.id, *selected_users.map(&:id)],
        )
      end

      it "resolves decomposed Unicode usernames" do
        SiteSetting.unicode_usernames = true
        unicode_user = Fabricate(:user, username: "café猫")
        authorize("mcp:groups:write")
        call_tool(
          "discourse_manage_group_members",
          {
            group_id: group.id,
            action: "add",
            usernames: [unicode_user.username.unicode_normalize(:nfd)],
          },
        )

        expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
        expect(group.users).to include(unicode_user)
      end

      it "reports unknown usernames and makes no partial membership change" do
        authorize("mcp:groups:write")
        unknown_username = "missing_group_user"
        [[member.username, unknown_username], [unknown_username]].each do |usernames|
          expect do
            call_tool(
              "discourse_manage_group_members",
              { group_id: group.id, action: "add", usernames: },
            )
          end.not_to change { group.group_users.count }

          expect(response.parsed_body.dig("result", "isError")).to eq(true)
          expect(tool_error).to eq(
            I18n.t("groups.errors.users_not_found", values: unknown_username),
          )
        end
      end

      it "adds and removes members by username" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_manage_group_members",
          { group_id: group.id, action: "add", usernames: [member.username] },
        )

        expect(response.status).to eq(200)
        expect(structured_content["usernames"]).to eq([member.username])
        expect(group.reload.users).to include(member)

        call_tool(
          "discourse_manage_group_members",
          { group_id: group.id, action: "remove", user_ids: [member.id] },
        )

        expect(response.status).to eq(200)
        expect(group.reload.users).not_to include(member)
      end

      it "reports existing members as skipped when adding a mixed selection" do
        authorize("mcp:groups:write")

        expect_enqueued_with(
          job: :notify_users_added_to_group,
          args: {
            user_ids: [member.id],
            group_id: group.id,
          },
        ) do
          call_tool(
            "discourse_manage_group_members",
            {
              group_id: group.id,
              action: "add",
              usernames: [user.username, member.username],
              notify_users: true,
            },
          )
        end

        expect(response.status).to eq(200)
        expect(structured_content["usernames"]).to eq([member.username])
        expect(structured_content["skipped_usernames"]).to eq([user.username])
        expect(group.reload.users).to contain_exactly(user, member)
      end

      it "reports users who were never members as skipped" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_manage_group_members",
          { group_id: group.id, action: "remove", usernames: [member.username] },
        )

        expect(structured_content["skipped_usernames"]).to eq([member.username])
      end

      it "requires a user selector" do
        authorize("mcp:groups:write")

        call_tool("discourse_manage_group_members", { group_id: group.id, action: "add" })

        expect(tool_error).to eq(I18n.t("mcp.errors.group_member_selector_required"))
      end

      it "refuses a member who does not own the group" do
        group.add(member)
        authorize("mcp:groups:write", auth_user: member)

        call_tool(
          "discourse_manage_group_members",
          { group_id: group.id, action: "add", usernames: [user.username] },
        )

        expect(response.status).to eq(403)
      end

      it "refuses an automatic group" do
        authorize("mcp:groups:write", auth_user: Fabricate(:admin, refresh_auto_groups: true))

        call_tool(
          "discourse_manage_group_members",
          {
            group_id: Group::AUTO_GROUPS[:trust_level_1],
            action: "add",
            usernames: [member.username],
          },
        )

        expect(response.status).to eq(403)
      end
    end

    describe "discourse_invite_group_members" do
      it "adds known addresses and invites the rest" do
        admin = Fabricate(:admin, refresh_auto_groups: true)
        authorize("mcp:groups:write", auth_user: admin)

        call_tool(
          "discourse_invite_group_members",
          { group_id: group.id, emails: [member.email, "newcomer@example.com"] },
        )

        expect(response.status).to eq(200)
        expect(structured_content["usernames"]).to eq([member.username])
        expect(structured_content["emails"]).to eq(["newcomer@example.com"])
        expect(group.reload.users).to include(member)
        expect(Invite.last.groups).to eq([group])
      end

      it "refuses a TL2 group owner who may invite but may not view emails" do
        owner = Fabricate(:user, trust_level: TrustLevel[2], refresh_auto_groups: true)
        make_owner(group, owner)
        authorize("mcp:groups:write", auth_user: owner)
        expect(owner.guardian.can_invite_to_forum?([group])).to eq(true)
        expect(owner.guardian.can_see_emails?).to eq(false)

        expect do
          call_tool(
            "discourse_invite_group_members",
            { group_id: group.id, emails: [member.email, "newcomer@example.com"] },
          )
        end.not_to change { Invite.count }

        expect(response.status).to eq(403)
        expect(response.body).not_to include(member.email, member.username)
        expect(group.reload.users).not_to include(member)
      end
    end

    describe "discourse_manage_group_owners" do
      before { make_owner(group, user) }

      it "lets an owner grant ownership and an admin revoke it" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_manage_group_owners",
          { group_id: group.id, action: "add", usernames: [member.username] },
        )

        expect(response.status).to eq(200)
        expect(group.group_users.find_by(user: member).owner).to eq(true)

        authorize("mcp:groups:write", auth_user: Fabricate(:admin, refresh_auto_groups: true))
        call_tool(
          "discourse_manage_group_owners",
          { group_id: group.id, action: "remove", usernames: [member.username] },
        )

        expect(response.status).to eq(200)
        expect(group.group_users.find_by(user: member).owner).to eq(false)
        expect(group.reload.users).to include(member)
      end

      it "refuses owner removal by a non-staff owner even with write scope" do
        make_owner(group, member)
        authorize("mcp:groups:write")

        call_tool(
          "discourse_manage_group_owners",
          { group_id: group.id, action: "remove", user_ids: [member.id] },
        )

        expect(response.status).to eq(403)
        expect(group.group_users.find_by(user: member)).to be_owner
      end

      it "allows moderator owner removal only when they can manage the group" do
        moderator = Fabricate(:moderator, refresh_auto_groups: true)
        make_owner(group, member)
        authorize("mcp:groups:write", auth_user: moderator)

        SiteSetting.moderators_manage_groups = false
        call_tool(
          "discourse_manage_group_owners",
          { group_id: group.id, action: "remove", user_ids: [member.id] },
        )
        expect(response.status).to eq(403)
        expect(group.group_users.find_by(user: member)).to be_owner

        SiteSetting.moderators_manage_groups = true
        call_tool(
          "discourse_manage_group_owners",
          { group_id: group.id, action: "remove", user_ids: [member.id] },
        )
        expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
        expect(group.group_users.find_by(user: member)).not_to be_owner
      end

      it "refuses an automatic group" do
        authorize("mcp:groups:write", auth_user: Fabricate(:admin, refresh_auto_groups: true))

        call_tool(
          "discourse_manage_group_owners",
          {
            group_id: Group::AUTO_GROUPS[:trust_level_1],
            action: "add",
            usernames: [member.username],
          },
        )

        expect(tool_error).to eq(I18n.t("groups.errors.can_not_modify_automatic"))
      end
    end

    describe "discourse_manage_group_membership" do
      it "joins and leaves a group that allows public admission and exit" do
        group.update!(public_admission: true, public_exit: true)
        authorize("mcp:groups:write")

        call_tool("discourse_manage_group_membership", { group_id: group.id, action: "join" })

        expect(response.status).to eq(200)
        expect(structured_content).to include("changed" => true, "member" => true)
        expect(group.reload.users).to include(user)

        call_tool("discourse_manage_group_membership", { group_id: group.id, action: "leave" })

        expect(structured_content).to include("changed" => true, "member" => false)
        expect(group.reload.users).not_to include(user)
      end

      it "refuses to join a group that does not allow public admission" do
        authorize("mcp:groups:write")

        call_tool("discourse_manage_group_membership", { group_id: group.id, action: "join" })

        expect(response.status).to eq(403)
        expect(group.reload.users).not_to include(user)
      end

      it "requests membership and messages the owners" do
        owner = Fabricate(:user)
        make_owner(group, owner)
        group.update!(allow_membership_requests: true)
        authorize("mcp:groups:write")

        call_tool(
          "discourse_manage_group_membership",
          { group_id: group.id, action: "request", reason: "I write the docs 猫" },
        )

        expect(response.status).to eq(200)
        expect(GroupRequest.find_by(group:, user:).reason).to eq("I write the docs 猫")
        topic = Topic.find(structured_content["topic_id"])
        expect(topic.archetype).to eq(Archetype.private_message)
        expect(topic.allowed_users).to include(owner)
      end

      it "requires a reason to request membership" do
        make_owner(group, Fabricate(:user))
        group.update!(allow_membership_requests: true)
        authorize("mcp:groups:write")

        call_tool("discourse_manage_group_membership", { group_id: group.id, action: "request" })

        expect(tool_error).to eq(I18n.t("mcp.errors.group_request_reason_required"))
      end
    end

    describe "discourse_handle_group_membership_request" do
      fab!(:requester, :user)

      before do
        make_owner(group, user)
        group.update!(allow_membership_requests: true)
        GroupMembershipRequester.request(requester.guardian, group, "I write the docs")
      end

      it "approves a request and adds the requester" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_handle_group_membership_request",
          { group_id: group.id, username: requester.username, action: "approve" },
        )

        expect(response.status).to eq(200)
        expect(structured_content).to include("accepted" => true)
        expect(group.reload.users).to include(requester)
        expect(GroupRequest.where(group:, user: requester)).to be_empty
      end

      it "denies a request without adding the requester" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_handle_group_membership_request",
          { group_id: group.id, username: requester.username, action: "deny" },
        )

        expect(response.status).to eq(200)
        expect(structured_content).to include("accepted" => false)
        expect(group.reload.users).not_to include(requester)
        expect(GroupRequest.where(group:, user: requester)).to be_empty
      end

      it "reports a user with no pending request" do
        authorize("mcp:groups:write")

        call_tool(
          "discourse_handle_group_membership_request",
          { group_id: group.id, username: member.username, action: "approve" },
        )

        expect(tool_error).to eq(I18n.t("mcp.errors.group_membership_request_not_found"))
      end

      it "does not tell a non-owner whether a request exists" do
        authorize("mcp:groups:write", auth_user: member)

        call_tool(
          "discourse_handle_group_membership_request",
          { group_id: group.id, username: requester.username, action: "approve" },
        )

        expect(response.status).to eq(403)
        expect(response.body).not_to include(requester.username)
      end
    end
  end
end
