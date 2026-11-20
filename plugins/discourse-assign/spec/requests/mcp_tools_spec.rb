# frozen_string_literal: true

describe "MCP topic assignments" do
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:assignee, :user)
  fab!(:group)
  fab!(:first_post, :post)
  fab!(:reply) { Fabricate(:post, topic: first_post.topic) }
  fab!(:assignment) do
    Fabricate(
      :topic_assignment,
      topic: first_post.topic,
      target: first_post.topic,
      assigned_to: assignee,
      assigned_by_user: admin,
      note: "Note 猫",
      status: "In progress",
    )
  end

  before do
    SiteSetting.mcp_server_enabled = true
    SiteSetting.assign_enabled = true
    SiteSetting.assigns_public = false
    SiteSetting.enable_assign_status = true
    SiteSetting.assign_statuses = "In progress|Done"
    %w[discourse_read_topic discourse_filter_topics].each do |identifier|
      McpPrimitive.create!(kind: "tool", identifier:, enabled: true)
    end
  end

  def authorize(actor = admin, scopes: [DiscourseMcp::Scopes::CONTENT_READ])
    group.add(actor)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group:, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Assignment tools",
        registration_type: "pre_registered",
        trust_state: "approved",
        redirect_uris: ["http://127.0.0.1/callback"],
      )
    authorization =
      DiscourseMcp::OAuth::AuthorizationGrant.create!(
        user: actor,
        client:,
        redirect_uri: client.redirect_uris.first,
        requested_scopes: scopes,
      )
    @token = McpOauthAccessToken.issue!(authorization:)
  end

  def call_tool(name, arguments)
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
    response.parsed_body.dig("result", "structuredContent")
  end

  def read_topic
    call_tool("discourse_read_topic", topic_id: first_post.topic_id)
  end

  def filter_topic
    call_tool("discourse_filter_topics", view: "filtered", filter: "in:all")
      .fetch("results")
      .find { |topic| topic["id"] == first_post.topic_id }
  end

  it "returns direct and visible reply assignments for permitted readers" do
    authorize
    Fabricate(
      :post_assignment,
      topic: first_post.topic,
      target: reply,
      assigned_to: group,
      assigned_by_user: admin,
      note: "Reply 猫",
    )

    [read_topic, filter_topic].each do |topic|
      data = topic.dig("plugin_data", "discourse-assign")
      expect(data).to include(
        "assigned_to_user" => include("username" => assignee.username),
        "assignment_note" => assignment.note,
        "assignment_status" => assignment.status,
      )
      expect(data.fetch("indirectly_assigned_to").fetch(reply.id.to_s)).to include(
        "post_number" => reply.post_number,
        "assignment_note" => "Reply 猫",
        "assigned_to" => include("name" => group.name),
      )
    end
  end

  it "returns group assignments and omits status when the status feature is disabled" do
    authorize
    assignment.update!(assigned_to: group)
    SiteSetting.enable_assign_status = false

    [read_topic, filter_topic].each do |topic|
      data = topic.dig("plugin_data", "discourse-assign")
      expect(data).to include("assigned_to_group" => include("name" => group.name))
      expect(data).not_to have_key("assigned_to_user")
      expect(data).not_to have_key("assignment_status")
    end
  end

  it "omits private assignment details for readers who cannot assign" do
    authorize(user)
    [read_topic, filter_topic].each { |topic| expect(topic).not_to have_key("plugin_data") }
    expect(response.body).not_to include(assignment.note)
  end

  it "allows public assignment details without granting assignment permissions" do
    authorize(user)
    SiteSetting.assigns_public = true
    [read_topic, filter_topic].each do |topic|
      expect(topic.dig("plugin_data", "discourse-assign", "assigned_to_user", "username")).to eq(
        assignee.username,
      )
    end
  end

  it "allows category-scoped assignment readers" do
    authorize(user)
    category = Fabricate(:category)
    category.custom_fields[
      DiscourseAssign::AssignmentPermissions::CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS
    ] = group.id.to_s
    category.save_custom_fields
    first_post.topic.update!(category:)

    [read_topic, filter_topic].each do |topic|
      expect(topic.dig("plugin_data", "discourse-assign", "assignment_note")).to eq(assignment.note)
    end
  end

  it "omits inactive assignments and assignments to inaccessible replies" do
    authorize(user)
    SiteSetting.assigns_public = true
    assignment.update!(active: false)
    deleted = Fabricate(:post, topic: first_post.topic, deleted_at: Time.current)
    Fabricate(
      :post_assignment,
      topic: first_post.topic,
      target: deleted,
      assigned_to: assignee,
      assigned_by_user: admin,
      note: "Deleted reply note 猫",
    )
    reply.update!(hidden: true)
    Fabricate(
      :post_assignment,
      topic: first_post.topic,
      target: reply,
      assigned_to: assignee,
      assigned_by_user: admin,
      note: "Hidden reply note 猫",
    )

    [read_topic, filter_topic].each { |topic| expect(topic).not_to have_key("plugin_data") }
    expect(response.body).not_to include("Hidden reply note 猫", "Deleted reply note 猫")
  end

  it "does not expose stale reply assignments after a move into a private message" do
    authorize(user)
    SiteSetting.assigns_public = true
    message = Fabricate(:private_message_post, user: admin, recipient: user)
    Fabricate(
      :post_assignment,
      topic: first_post.topic,
      target: reply,
      assigned_to: assignee,
      assigned_by_user: admin,
      note: "Moved reply note 猫",
    )
    reply.update!(topic: message.topic)

    [read_topic, filter_topic].each do |topic|
      data = topic.dig("plugin_data", "discourse-assign")
      expect(data).to include("assignment_note" => assignment.note)
      expect(data).not_to have_key("indirectly_assigned_to")
    end
    expect(response.body).not_to include("Moved reply note 猫")
  end

  it "does not expose private-message assignments without the dedicated read scope" do
    message = Fabricate(:private_message_post, user: admin, recipient: user)
    Fabricate(
      :topic_assignment,
      topic: message.topic,
      assigned_to: assignee,
      assigned_by_user: admin,
      note: "Private note 猫",
    )
    authorize(user)
    SiteSetting.assigns_public = true

    expect(call_tool("discourse_read_topic", topic_id: message.topic_id)).to be_nil
    expect(response.status).to eq(403)
    expect(response.body).not_to include("Private note 猫")

    authorize(
      user,
      scopes: [DiscourseMcp::Scopes::CONTENT_READ, DiscourseMcp::Scopes::PRIVATE_MESSAGES_READ],
    )
    data = call_tool("discourse_read_topic", topic_id: message.topic_id)
    expect(data.dig("plugin_data", "discourse-assign", "assignment_note")).to eq("Private note 猫")
  end

  it "keeps category-scoped permissions separate for subcategories" do
    authorize(user)
    parent = Fabricate(:category)
    child = Fabricate(:category, parent_category: parent)
    parent.custom_fields[
      DiscourseAssign::AssignmentPermissions::CATEGORY_ADDITIONAL_ASSIGN_ALLOWED_GROUPS
    ] = group.id.to_s
    parent.save_custom_fields
    first_post.topic.update!(category: child)

    [read_topic, filter_topic].each { |topic| expect(topic).not_to have_key("plugin_data") }
  end

  it "omits assignment data when the plugin is disabled" do
    authorize
    SiteSetting.assign_enabled = false
    [read_topic, filter_topic].each { |topic| expect(topic).not_to have_key("plugin_data") }
  end
end
