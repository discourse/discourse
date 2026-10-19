# frozen_string_literal: true

describe "MCP category tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin)
  fab!(:scope_group, :group)

  before do
    SiteSetting.mcp_server_enabled = true
    scope_group.add(user)
    %w[
      discourse_create_category
      discourse_get_category
      discourse_update_category
      discourse_delete_category
    ].each { |identifier| McpPrimitive.create!(kind: "tool", identifier:, enabled: true) }
  end

  def authorize(*extra_scopes, auth_user: user)
    scope_group.add(auth_user)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "Category tool test client",
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
  end

  def call_create_category(arguments)
    call_tool("discourse_create_category", arguments)
  end

  it "requires the category write scope" do
    authorize

    call_create_category(name: "Missing scope")

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:categories:write"',
    )
    expect(Category.find_by(name: "Missing scope")).to be_nil
  end

  it "does not let a regular user create a category when the token has scope" do
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE)

    call_create_category(name: "Not allowed", parent_category_id: 999_999_999)

    expect(response.status).to eq(403)
    expect(Category.find_by(name: "Not allowed")).to be_nil
  end

  it "creates a subcategory and logs the action for an authorized admin" do
    parent_category = Fabricate(:category)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    expect do
      call_create_category(
        name: "猫 support",
        description: "Help with cats",
        parent_category_id: parent_category.id,
        color: "0088CC",
        text_color: "FFFFFF",
        emoji: "cat",
        icon: "paw",
      )
    end.to change {
      UserHistory.where(
        action: UserHistory.actions[:create_category],
        acting_user_id: admin.id,
      ).count
    }.by(1)

    expect(response.status).to eq(200)
    result = response.parsed_body.dig("result", "structuredContent")
    category = Category.find(result.fetch("id"))
    expect(result).to include("name" => "猫 support", "slug" => category.slug)
    expect(category).to have_attributes(
      parent_category_id: parent_category.id,
      user_id: admin.id,
      style_type: "emoji",
      emoji: "cat",
      icon: "paw",
    )
  end

  it "rejects a public subcategory beneath a private parent" do
    group = Fabricate(:group)
    parent = Fabricate(:private_category, group:)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    expect do
      call_create_category(name: "Public child", parent_category_id: parent.id)
    end.not_to change(Category, :count)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(Guardian.new.can_see?(parent)).to eq(false)
  end

  it "rejects moving a public category beneath a private parent" do
    group = Fabricate(:group)
    parent = Fabricate(:private_category, group:)
    category = Fabricate(:category)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    call_tool("discourse_update_category", category_id: category.id, parent_category_id: parent.id)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(category.reload.parent_category_id).to be_nil
    expect(Guardian.new.can_see?(category)).to eq(true)
    expect(Guardian.new.can_see?(parent)).to eq(false)
  end

  it "does not create a category with an invalid emoji" do
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    call_create_category(name: "Invalid emoji", emoji: "not-a-real-emoji")

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(Category.find_by(name: "Invalid emoji")).to be_nil
  end

  it "does not create a subcategory under a deleted category" do
    parent_category = Fabricate(:category)
    parent_category.destroy!
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    call_create_category(name: "Orphaned", parent_category_id: parent_category.id)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.parsed_body.dig("result", "content")).to eq(
      [{ "type" => "text", "text" => I18n.t("category.errors.not_found") }],
    )
    expect(Category.find_by(name: "Orphaned")).to be_nil
  end

  it "requires the category read scope for management details" do
    category = Fabricate(:category)
    authorize

    call_tool("discourse_get_category", category_id: category.id)

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:categories:read"',
    )
  end

  it "returns a tool error when a category has been deleted" do
    category = Fabricate(:category)
    category.destroy!
    authorize(DiscourseMcp::Scopes::CATEGORIES_READ, auth_user: admin)

    call_tool("discourse_get_category", category_id: category.id)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.parsed_body.dig("result", "content")).to eq(
      [{ "type" => "text", "text" => I18n.t("mcp.errors.category_not_found") }],
    )
  end

  it "requires the category write scope to update a category" do
    category = Fabricate(:category, name: "Original")
    authorize(DiscourseMcp::Scopes::CATEGORIES_READ, auth_user: admin)

    call_tool("discourse_update_category", category_id: category.id, name: "Changed")

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:categories:write"',
    )
    expect(category.reload.name).to eq("Original")
  end

  it "requires the category write scope to delete a category" do
    category = Fabricate(:category)
    authorize(DiscourseMcp::Scopes::CATEGORIES_READ, auth_user: admin)

    call_tool(
      "discourse_delete_category",
      category_id: category.id,
      expected_name: category.name,
      confirm: true,
    )

    expect(response.status).to eq(403)
    expect(response.headers["WWW-Authenticate"]).to include(
      'error="insufficient_scope"',
      'scope="mcp:categories:write"',
    )
    expect(Category.exists?(category.id)).to eq(true)
  end

  it "does not let a regular user manage categories when the token has scope" do
    category = Fabricate(:category, name: "Original")
    authorize(DiscourseMcp::Scopes::CATEGORIES_READ, DiscourseMcp::Scopes::CATEGORIES_WRITE)

    call_create_category(name: "Not allowed")
    expect(response.status).to eq(403)

    call_tool("discourse_get_category", category_id: category.id)
    expect(response.status).to eq(403)

    call_tool("discourse_update_category", category_id: category.id, name: "Changed")
    expect(response.status).to eq(403)

    call_tool(
      "discourse_delete_category",
      category_id: category.id,
      expected_name: category.name,
      confirm: true,
    )
    expect(response.status).to eq(403)

    expect(Category.find_by(name: "Not allowed")).to be_nil
    expect(category.reload.name).to eq("Original")
  end

  it "lets an authorized admin read and update basic category details" do
    parent_category = Fabricate(:category)
    category = Fabricate(:category_with_definition, name: "Original", user: admin)
    authorize(
      DiscourseMcp::Scopes::CATEGORIES_READ,
      DiscourseMcp::Scopes::CATEGORIES_WRITE,
      auth_user: admin,
    )

    call_tool("discourse_get_category", category_id: category.id)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent", "category")).to include(
      "id" => category.id,
      "name" => "Original",
      "can_delete" => true,
    )

    call_tool(
      "discourse_update_category",
      category_id: category.id,
      name: "猫 support",
      description: "Updated **description**",
      parent_category_id: parent_category.id,
      emoji: "cat",
    )

    expect(response.status).to eq(200)
    result = response.parsed_body.dig("result", "structuredContent", "category")
    expect(result).to include(
      "id" => category.id,
      "name" => "猫 support",
      "parent_category_id" => parent_category.id,
      "description" => "Updated **description**",
      "style_type" => "emoji",
      "emoji" => "cat",
    )
    expect(category.reload.topic.first_post.raw).to eq("Updated **description**")
    history =
      UserHistory.find_by(
        action: UserHistory.actions[:change_category_settings],
        acting_user_id: admin.id,
        category_id: category.id,
        subject: "name",
      )
    expect(history).to have_attributes(previous_value: "Original", new_value: "猫 support")
  end

  it "does not persist or log an invalid category update" do
    category = Fabricate(:category, name: "Original")
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    expect do
      call_tool("discourse_update_category", category_id: category.id, emoji: "not-an-emoji")
    end.not_to change {
      UserHistory.where(
        action: UserHistory.actions[:change_category_settings],
        category_id: category.id,
      ).count
    }

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(category.reload.style_type).to eq("square")
  end

  it "uses moderator category permissions in addition to OAuth scope" do
    SiteSetting.moderators_manage_categories = true
    moderator = Fabricate(:moderator)
    visible_category = Fabricate(:category, name: "Visible")
    group = Fabricate(:group)
    hidden_category = Fabricate(:private_category, group:)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: moderator)

    call_tool(
      "discourse_update_category",
      category_id: visible_category.id,
      name: "Updated by moderator",
    )
    expect(response.status).to eq(200)

    call_tool("discourse_update_category", category_id: hidden_category.id, name: "Not visible")
    expect(response.status).to eq(403)

    call_tool(
      "discourse_update_category",
      category_id: visible_category.id,
      parent_category_id: hidden_category.id,
    )
    expect(response.status).to eq(403)

    call_tool(
      "discourse_delete_category",
      category_id: hidden_category.id,
      expected_name: "Guessed name",
      confirm: true,
    )
    expect(response.status).to eq(403)

    expect(visible_category.reload.name).to eq("Updated by moderator")
    expect(visible_category.parent_category_id).to be_nil
    expect(hidden_category.reload.name).not_to eq("Not visible")
  end

  it "requires explicit confirmation and the current name before deleting" do
    category = Fabricate(:category)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    call_tool(
      "discourse_delete_category",
      category_id: category.id,
      expected_name: category.name,
      confirm: false,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)

    call_tool(
      "discourse_delete_category",
      category_id: category.id,
      expected_name: "Wrong name",
      confirm: true,
    )
    expect(response.parsed_body.dig("result", "isError")).to eq(true)

    expect(Category.exists?(category.id)).to eq(true)
  end

  it "deletes an empty category and logs the action for an authorized admin" do
    category = Fabricate(:category)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    expect do
      call_tool(
        "discourse_delete_category",
        category_id: category.id,
        expected_name: category.name,
        confirm: true,
      )
    end.to change {
      UserHistory.where(
        action: UserHistory.actions[:delete_category],
        acting_user_id: admin.id,
        category_id: category.id,
      ).count
    }.by(1)

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "structuredContent")).to eq(
      "deleted" => true,
      "category_id" => category.id,
    )
    expect(Category.exists?(category.id)).to eq(false)
  end

  it "does not delete a category that contains topics" do
    category = Fabricate(:category)
    category.update!(topic_count: 1)
    authorize(DiscourseMcp::Scopes::CATEGORIES_WRITE, auth_user: admin)

    call_tool(
      "discourse_delete_category",
      category_id: category.id,
      expected_name: category.name,
      confirm: true,
    )

    expect(response.status).to eq(403)
    expect(Category.exists?(category.id)).to eq(true)
  end
end
