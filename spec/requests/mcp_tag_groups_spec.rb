# frozen_string_literal: true

describe "MCP tag groups" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:scope_group, :group)
  fab!(:tag_group)
  fab!(:tag)

  before do
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
  end

  def authorize(
    actor = admin,
    scopes: %w[mcp:content:read mcp:tag-groups:read mcp:tag-groups:write]
  )
    scope_group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Tag groups",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    grant =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: actor,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization: grant)
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
           "HTTP_MCP_METHOD" => "tools/call",
           "HTTP_MCP_NAME" => name,
         }
  end

  def operations
    {
      "discourse_list_tag_groups" => {
      },
      "discourse_get_tag_group" => {
        tag_group_id: tag_group.id,
      },
      "discourse_create_tag_group" => {
        name: "New group",
      },
      "discourse_update_tag_group" => {
        tag_group_id: tag_group.id,
        name: "Changed",
      },
      "discourse_delete_tag_group" => {
        tag_group_id: tag_group.id,
        expected_name: tag_group.name,
        confirm: true,
      },
    }
  end

  it "requires authentication" do
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(401)
    end
  end

  it "denies ordinary users even with all management scopes" do
    original_name = tag_group.name
    authorize(user)
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403), name
    end
    expect(tag_group.reload.name).to eq(original_name)
    expect(TagGroup.count).to eq(1)
  end

  it "denies staff without the required scopes" do
    authorize(scopes: [])
    operations.each do |name, arguments|
      call_tool(name, arguments)
      expect(response.status).to eq(403), name
    end
    expect(TagGroup.count).to eq(1)
  end

  it "allows moderators to create, read, update and delete groups with normal staff logging" do
    authorize(moderator)
    call_tool(
      "discourse_create_tag_group",
      name: "猫",
      tags: [{ id: tag.id }],
      permissions: {
        "0" => "readonly",
      },
      one_per_topic: true,
    )
    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "猫")
    expect(group.tags).to contain_exactly(tag)
    expect(group.tag_group_permissions.pluck(:group_id, :permission_type)).to eq([[0, 3]])
    call_tool("discourse_get_tag_group", tag_group_id: group.id)
    expect(response.parsed_body.dig("result", "structuredContent", "tag_group", "id")).to eq(
      group.id,
    )
    call_tool("discourse_update_tag_group", tag_group_id: group.id, name: "猫 renamed")
    expect(response.status).to eq(200)
    expect(group.reload.tags).to contain_exactly(tag)
    expect(group.one_per_topic).to eq(true)
    expect(group.tag_group_permissions.pluck(:permission_type)).to eq([3])
    call_tool("discourse_list_tag_groups", limit: 1)
    expect(response.parsed_body.dig("result", "structuredContent", "has_more")).to eq(true)
    category = Fabricate(:category)
    CategoryTagGroup.create!(category:, tag_group: group)
    call_tool(
      "discourse_delete_tag_group",
      tag_group_id: group.id,
      expected_name: group.name,
      confirm: true,
    )
    expect(response.status).to eq(200)
    expect(TagGroup.exists?(group.id)).to eq(false)
    expect(CategoryTagGroup.exists?(tag_group_id: group.id)).to eq(false)
    expect(Tag.exists?(tag.id)).to eq(true)
    actions = UserHistory.where(acting_user_id: moderator.id).pluck(:action)
    expect(actions).to include(
      UserHistory.actions[:tag_group_create],
      UserHistory.actions[:tag_group_change],
      UserHistory.actions[:tag_group_destroy],
    )
  end

  it "preserves omitted parent tags and permits explicitly clearing associations" do
    parent = Fabricate(:tag)
    tag_group.update!(tags: [tag], parent_tag: parent, one_per_topic: true)
    authorize
    call_tool("discourse_update_tag_group", tag_group_id: tag_group.id, name: "Renamed")
    expect(tag_group.reload.parent_tag).to eq(parent)
    expect(tag_group.tags).to contain_exactly(tag)
    call_tool(
      "discourse_update_tag_group",
      tag_group_id: tag_group.id,
      parent_tag: nil,
      tags: [],
      one_per_topic: false,
    )
    expect(response.status).to eq(200)
    expect(tag_group.reload.parent_tag).to be_nil
    expect(tag_group.tags).to be_empty
    expect(tag_group.one_per_topic).to eq(false)
  end

  it "filters public discovery by both group and tag visibility without exposing staff settings" do
    private_group = Fabricate(:tag_group, permissions: { Group::AUTO_GROUPS[:staff] => :full })
    hidden = Fabricate(:tag)
    private_group.tags << hidden
    CategoryTag.create!(
      category: Fabricate(:private_category, group: Fabricate(:group)),
      tag: hidden,
    )
    tag_group.tags << [tag, hidden]
    authorize(user)
    call_tool("discourse_search_tag_groups")
    expect(response.status).to eq(200)
    results = response.parsed_body.dig("result", "structuredContent", "results")
    expect(results.map { |group| group["name"] }).to contain_exactly(tag_group.name)
    expect(results.first.keys).to contain_exactly("name", "tags")
    expect(results.first["tags"].map { |record| record["id"] }).to contain_exactly(tag.id)
  end

  it "allows a group member to discover restricted groups" do
    restricted = Fabricate(:tag_group, permissions: { scope_group.id => :readonly })
    authorize(user)
    call_tool("discourse_search_tag_groups", names: [restricted.name.upcase])
    expect(
      response
        .parsed_body
        .dig("result", "structuredContent", "results")
        .map { |record| record["name"] },
    ).to eq([restricted.name])
  end

  it "requires exact deletion confirmation" do
    authorize
    call_tool(
      "discourse_delete_tag_group",
      tag_group_id: tag_group.id,
      expected_name: "wrong",
      confirm: true,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(TagGroup.exists?(tag_group.id)).to eq(true)
  end

  it "rejects unknown IDs and unauthorized tag creation before changing state" do
    authorize
    [
      { tags: [{ id: 999_999 }] },
      { permissions: { "999999" => "full" } },
      { tags: [{ name: "newtag" }] },
    ].each do |attributes|
      call_tool("discourse_update_tag_group", { tag_group_id: tag_group.id }.merge(attributes))
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end
    expect(Tag.exists?(name: "newtag")).to eq(false)
  end

  it "creates named tags only with explicit consent and rolls them back on validation failure" do
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: tag_group.name,
      tags: [{ name: "rollbacktag" }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(Tag.exists?(name: "rollbacktag")).to eq(false)
    call_tool(
      "discourse_create_tag_group",
      name: "Named tags",
      tags: [{ name: "newtag" }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(TagGroup.find_by!(name: "Named tags").tags.pluck(:name)).to eq(["newtag"])
  end

  it "keeps staff reads available but blocks mutations when tagging is disabled" do
    authorize
    SiteSetting.tagging_enabled = false
    call_tool("discourse_list_tag_groups")
    expect(response.status).to eq(200)
    call_tool("discourse_update_tag_group", tag_group_id: tag_group.id, name: "Changed")
    expect(response.status).not_to eq(200)
    expect(tag_group.reload.name).not_to eq("Changed")
  end

  it "separates read and write scopes" do
    authorize(scopes: [DiscourseMcp::Scopes::TAG_GROUPS_READ])
    call_tool("discourse_list_tag_groups")
    expect(response.status).to eq(200)
    call_tool("discourse_update_tag_group", tag_group_id: tag_group.id, name: "Denied")
    expect(response.status).to eq(403)
    authorize(scopes: [DiscourseMcp::Scopes::TAG_GROUPS_WRITE])
    call_tool("discourse_get_tag_group", tag_group_id: tag_group.id)
    expect(response.status).to eq(403)
    expect(tag_group.reload.name).not_to eq("Denied")
  end

  it "does not discover tag groups limited to private categories" do
    restricted = Fabricate(:tag_group)
    CategoryTagGroup.create!(
      category: Fabricate(:private_category, group: Fabricate(:group)),
      tag_group: restricted,
    )
    authorize(user)
    call_tool("discourse_search_tag_groups")
    expect(
      response
        .parsed_body
        .dig("result", "structuredContent", "results")
        .map { |record| record["name"] },
    ).to eq([tag_group.name])
  end

  it "rolls back newly created tags and association changes when an update fails" do
    original = tag_group.name
    other = Fabricate(:tag_group)
    tag_group.tags << tag
    authorize
    call_tool(
      "discourse_update_tag_group",
      tag_group_id: tag_group.id,
      name: other.name,
      tags: [{ name: "failedtag" }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(tag_group.reload.name).to eq(original)
    expect(tag_group.tags).to contain_exactly(tag)
    expect(Tag.exists?(name: "failedtag")).to eq(false)
  end

  it "returns a tool error for a deleted tag group" do
    id = tag_group.id
    tag_group.destroy!
    authorize
    call_tool("discourse_get_tag_group", tag_group_id: id)
    expect(response.status).not_to eq(500)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
  end

  it "does not apply the per-topic tag limit to group members" do
    SiteSetting.max_tags_per_topic = 2
    authorize
    names = %w[first second third]
    call_tool(
      "discourse_create_tag_group",
      name: "Many tags",
      tags: names.map { |name| { name: } },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(TagGroup.find_by!(name: "Many tags").tags.pluck(:name)).to contain_exactly(*names)
  end

  it "lists additional tag groups without querying their tags and permissions individually" do
    tag_group.tags << tag
    authorize
    call_tool("discourse_list_tag_groups")
    initial_queries = track_sql_queries { call_tool("discourse_list_tag_groups") }
    5.times { Fabricate(:tag_group, tags: [tag]) }
    expanded_queries = track_sql_queries { call_tool("discourse_list_tag_groups") }
    expect(response.parsed_body.dig("result", "structuredContent", "tag_groups").length).to eq(6)
    expect(expanded_queries.length).to be <= initial_queries.length + 1
  end

  it "rejects names that normalize to blank without clearing members or the parent" do
    parent = Fabricate(:tag)
    tag_group.update!(tags: [tag], parent_tag: parent)
    authorize
    [{ tags: [{ name: " " }] }, { parent_tag: { name: "###" } }].each do |attributes|
      call_tool(
        "discourse_update_tag_group",
        { tag_group_id: tag_group.id, allow_tag_creation: true }.merge(attributes),
      )
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
      expect(tag_group.reload.tags).to contain_exactly(tag)
      expect(tag_group.parent_tag).to eq(parent)
    end
  end

  it "resolves synonym IDs to original member and parent tags" do
    original_parent = Fabricate(:tag)
    synonym = Fabricate(:tag, target_tag_id: tag.id)
    parent_synonym = Fabricate(:tag, target_tag_id: original_parent.id)
    authorize
    call_tool(
      "discourse_update_tag_group",
      tag_group_id: tag_group.id,
      tags: [{ id: synonym.id }],
      parent_tag: {
        id: parent_synonym.id,
      },
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(tag_group.reload.base_tags).to contain_exactly(tag)
    expect(tag_group.parent_tag).to eq(original_parent)
    result = response.parsed_body.dig("result", "structuredContent", "tag_group")
    expect(result["tags"].map { |entry| entry["id"] }).to eq([tag.id])
    expect(result["parent_tag"].map { |entry| entry["id"] }).to eq([original_parent.id])
  end

  it "resolves synonym names to the same original tags returned by reads" do
    synonym = Fabricate(:tag, target_tag_id: tag.id)
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Canonical group",
      tags: [{ name: synonym.name }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "Canonical group")
    expect(group.base_tags).to contain_exactly(tag)
    expect(
      response
        .parsed_body
        .dig("result", "structuredContent", "tag_group", "tags")
        .map { |entry| entry["id"] },
    ).to eq([tag.id])
  end

  it "uses normal tag cleaning for new Unicode names" do
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Unicode group",
      tags: [{ name: "猫 new" }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(TagGroup.find_by!(name: "Unicode group").base_tags.pluck(:name)).to eq(
      [DiscourseTagging.clean_tag("猫 new")],
    )
  end

  it "resolves cleaned synonym names for members and parents" do
    parent = Fabricate(:tag)
    Fabricate(:tag, name: "alias-tag", target_tag_id: tag.id)
    Fabricate(:tag, name: "parent-alias", target_tag_id: parent.id)
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Cleaned aliases",
      tags: [{ name: " alias tag " }],
      parent_tag: {
        name: " parent alias ",
      },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "Cleaned aliases")
    expect(group.base_tags).to contain_exactly(tag)
    expect(group.parent_tag).to eq(parent)
  end

  it "resolves existing member and parent names without regard to case" do
    SiteSetting.force_lowercase_tags = false
    member = Fabricate(:tag, name: "member")
    parent = Fabricate(:tag, name: "parent")
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Existing tags",
      tags: [{ name: "Member" }],
      parent_tag: {
        name: "Parent",
      },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "Existing tags")
    expect(group.tags).to contain_exactly(member)
    expect(group.parent_tag).to eq(parent)
  end

  it "creates named parents independently of the per-topic tag limit" do
    SiteSetting.max_tags_per_topic = 0
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Named parent",
      parent_tag: {
        name: "first-parent",
      },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "Named parent")
    expect(group.parent_tag&.name).to eq("first-parent")

    call_tool(
      "discourse_update_tag_group",
      tag_group_id: group.id,
      parent_tag: {
        name: "second-parent",
      },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(group.reload.parent_tag&.name).to eq("second-parent")
  end

  it "prefers an existing literal tag name over a cleaned synonym name" do
    literal = Fabricate(:tag, name: "alias tag", slug: "literal-tag")
    parent = Fabricate(:tag, name: "parent alias", slug: "literal-parent")
    Fabricate(:tag, name: "alias-tag", target_tag_id: tag.id)
    Fabricate(:tag, name: "parent-alias", target_tag_id: tag.id)
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Literal names",
      tags: [{ name: literal.name.upcase }],
      parent_tag: {
        name: parent.name.upcase,
      },
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    group = TagGroup.find_by!(name: "Literal names")
    expect(group.tags).to contain_exactly(literal)
    expect(group.parent_tag).to eq(parent)
  end

  it "does not create a cleaned variant of an existing literal name on update" do
    literal = Fabricate(:tag, name: "literal tag", slug: "literal-name")
    authorize
    expect {
      call_tool(
        "discourse_update_tag_group",
        tag_group_id: tag_group.id,
        tags: [{ name: literal.name.upcase }],
        allow_tag_creation: true,
      )
    }.not_to change { Tag.count }
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(tag_group.reload.tags).to contain_exactly(literal)
  end

  it "preserves existing names that current cleaning would remove" do
    legacy = Fabricate(:tag, name: "###", slug: "legacy-tag")
    authorize
    call_tool(
      "discourse_create_tag_group",
      name: "Existing names",
      tags: [{ name: legacy.name }],
      allow_tag_creation: true,
    )
    expect(response.parsed_body.dig("result", "isError")).not_to eq(true)
    expect(TagGroup.find_by!(name: "Existing names").base_tags).to contain_exactly(legacy)
  end

  it "rejects a synonym whose original tag is missing without clearing members" do
    original = Fabricate(:tag)
    synonym = Fabricate(:tag, target_tag_id: original.id)
    tag_group.tags << tag
    Tag.where(id: original.id).delete_all
    authorize
    call_tool("discourse_update_tag_group", tag_group_id: tag_group.id, tags: [{ id: synonym.id }])
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(tag_group.reload.base_tags).to contain_exactly(tag)
  end

  it "rejects malformed selectors before resolving tags" do
    tag_group.tags << tag
    authorize
    [
      { tags: ["bug"] },
      { tags: [{}] },
      { tags: [{ id: tag.id.to_s }] },
      { parent_tag: { id: nil } },
    ].each do |attributes|
      call_tool("discourse_update_tag_group", { tag_group_id: tag_group.id }.merge(attributes))
      expect(response.status).to eq(400)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
    end
    expect(tag_group.reload.base_tags).to contain_exactly(tag)
  end

  it "rejects malformed permission maps before changing permissions" do
    authorize
    original_permissions = tag_group.tag_group_permissions.pluck(:group_id, :permission_type)
    [
      { "abc" => "full" },
      { "0\n" => "full" },
      {},
      { "0" => "unknown" },
      ["full"],
    ].each do |permissions|
      call_tool("discourse_update_tag_group", tag_group_id: tag_group.id, permissions:)
      expect(response.status).to eq(400)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
    end
    expect(tag_group.reload.tag_group_permissions.pluck(:group_id, :permission_type)).to eq(
      original_permissions,
    )
  end
end
