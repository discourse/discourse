# frozen_string_literal: true

describe "MCP user administration tools" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:moderator)
  fab!(:admin)
  fab!(:scope_group, :group)

  before { SiteSetting.mcp_server_enabled = true }

  it "rejects deactivation that would delete a pending account" do
    SiteSetting.must_approve_users = true
    pending_user = Fabricate(:user, active: true, approved: false)
    Jobs::CreateUserReviewable.new.execute(user_id: pending_user.id)
    authorize("mcp:users:write")

    call_tool(
      "discourse_manage_user_activation",
      { username: pending_user.username, action: "deactivate", confirm: true },
    )

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(pending_user.reload).to be_active
    expect(ReviewableUser.find_by(target: pending_user)).to be_pending
  end

  it "honors registration restrictions before creating an account" do
    authorize("mcp:users:write")
    arguments = {
      username: "restricted_signup",
      email: "restricted@example.com",
      name: "Restricted",
      password: "correct horse battery staple",
    }
    SiteSetting.allow_new_registrations = false
    call_tool("discourse_create_user", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(User.find_by_username(arguments[:username])).to be_nil

    SiteSetting.allow_new_registrations = true
    SiteSetting.invite_code = "invite-only"
    call_tool("discourse_create_user", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(User.find_by_username(arguments[:username])).to be_nil

    SiteSetting.invite_code = ""
    Fabricate(:user_field, requirement: :on_signup)
    call_tool("discourse_create_user", arguments)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(User.find_by_username(arguments[:username])).to be_nil
  end

  it "preserves explicit unapproved state despite domain auto approval" do
    SiteSetting.must_approve_users = true
    SiteSetting.auto_approve_email_domains = "example.com"
    authorize("mcp:users:write")
    call_tool(
      "discourse_create_user",
      {
        username: "unapproved_cat",
        email: "unapproved@example.com",
        name: "Cat",
        password: "correct horse battery staple",
        active: false,
        approved: false,
      },
    )
    expect(response.status).to eq(200)
    created_user = User.find_by_username("unapproved_cat")
    expect(created_user).not_to be_approved
    expect(created_user.approved_by_id).to be_nil
    expect(created_user.approved_at).to be_nil
  end

  def authorize(*extra_scopes, auth_user: admin)
    scope_group.add(auth_user)
    scopes = [DiscourseMcp::INITIAL_SCOPE, *extra_scopes]
    scopes.each { |scope| McpGroupScope.find_or_create_by!(group: scope_group, scope:) }
    client =
      McpOauthClient.create!(
        client_id: SecureRandom.hex,
        name: "User administration test client",
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

  it "requires dedicated read and write scopes" do
    authorize

    {
      "discourse_list_users" => [{}, "mcp:users:read"],
      "discourse_create_user" => [
        {
          username: "not_created",
          email: "not-created@example.com",
          name: "Not Created",
          password: "correct horse battery staple",
        },
        "mcp:users:write",
      ],
      "discourse_manage_user_activation" => [
        { username: user.username, action: "deactivate", confirm: true },
        "mcp:users:write",
      ],
    }.each do |name, (arguments, scope)|
      call_tool(name, arguments)

      aggregate_failures(name) do
        expect(response.status).to eq(403)
        expect(response.headers["WWW-Authenticate"]).to include(
          'error="insufficient_scope"',
          %(scope="#{scope}"),
        )
      end
    end

    expect(User.find_by_username("not_created")).to be_nil
    expect(user.reload).to be_active
  end

  it "does not let a regular user administer users when the token has both scopes" do
    authorize("mcp:users:read", "mcp:users:write", auth_user: user)

    call_tool("discourse_list_users")
    expect(response.status).to eq(403)

    call_tool(
      "discourse_create_user",
      {
        username: "not_created",
        email: "not-created@example.com",
        name: "Not Created",
        password: "correct horse battery staple",
      },
    )
    expect(response.status).to eq(403)

    call_tool(
      "discourse_manage_user_activation",
      { username: admin.username, action: "deactivate", confirm: true },
    )
    expect(response.status).to eq(403)
    expect(admin.reload).to be_active
  end

  it "denies each activation operation when a scoped user lacks authority" do
    SiteSetting.must_approve_users = true
    inactive_user = Fabricate(:inactive_user, approved: false)
    pending_user = Fabricate(:user, approved: false)
    authorize("mcp:users:write", auth_user: user)

    {
      "activate" => inactive_user,
      "activate_and_approve" => inactive_user,
      "approve" => pending_user,
      "deactivate" => admin,
    }.each do |action, target|
      call_tool(
        "discourse_manage_user_activation",
        { username: target.username, action: action, confirm: true },
      )
      expect(response.status).to eq(403)
    end

    expect(inactive_user.reload).not_to be_active
    expect(pending_user.reload).not_to be_approved
    expect(admin.reload).to be_active
  end

  it "lists filtered users with bounded pagination and optional email access" do
    matching_user = Fabricate(:user, username: "searchable_cat", email: "cat@example.com")
    Fabricate(:user, username: "unrelated_dog")
    authorize("mcp:users:read")

    expect do
      call_tool(
        "discourse_list_users",
        { filter: "searchable_cat", include_emails: true, limit: 1 },
      )
    end.to change {
      UserHistory.where(action: UserHistory.actions[:check_email], acting_user_id: admin.id).count
    }.by(1)

    expect(response.status).to eq(200)
    expect(structured_content["users"]).to contain_exactly(
      include(
        "id" => matching_user.id,
        "username" => matching_user.username,
        "email" => matching_user.email,
      ),
    )
    expect(structured_content["meta"]).to include("page" => 0, "limit" => 1, "has_more" => false)
  end

  it "lets staff list users without exposing email addresses they cannot inspect" do
    SiteSetting.moderators_view_emails = false
    target_user = Fabricate(:user, username: "private_email_cat", email: "private@example.com")
    authorize("mcp:users:read", auth_user: moderator)

    call_tool("discourse_list_users", { filter: target_user.username, include_emails: true })

    expect(response.status).to eq(200)
    expect(structured_content["users"].first).to include(
      "username" => target_user.username,
      "email" => nil,
    )
  end

  it "creates a user as an administrator without returning the password" do
    authorize("mcp:users:write")

    call_tool(
      "discourse_create_user",
      {
        username: "created_cat",
        email: "created-cat@example.com",
        name: "Created 猫",
        password: "correct horse battery staple",
      },
    )

    expect(response.status).to eq(200)
    created_user = User.find_by_username("created_cat")
    expect(created_user).to be_active.and be_approved
    expect(structured_content).to include(
      "created" => true,
      "user_id" => created_user.id,
      "username" => created_user.username,
      "active" => true,
      "approved" => true,
    )
    expect(response.body).not_to include("correct horse battery staple")
  end

  it "does not report a failed staged-user conversion as a successful creation" do
    existing_user = Fabricate(:user)
    staged_user = Fabricate(:staged, email: "staged-request@example.com")
    authorize("mcp:users:write")

    call_tool(
      "discourse_create_user",
      {
        username: existing_user.username,
        email: staged_user.email,
        name: "Staged Request",
        password: "correct horse battery staple",
      },
    )

    expect(response.status).to eq(200)
    expect(response.parsed_body.dig("result", "isError")).to eq(true)
    expect(response.body).not_to include("correct horse battery staple")
    expect(staged_user.reload).to be_staged
  end

  it "rejects whitespace-only passwords without creating or unstaging users" do
    staged_user = Fabricate(:staged, email: "blank-password@example.com")
    authorize("mcp:users:write")

    ["new-blank-password@example.com", staged_user.email].each do |email|
      expect do
        call_tool(
          "discourse_create_user",
          { username: "blank_password", email: email, name: "Blank Password", password: " " * 20 },
        )
      end.not_to change(User, :count)

      expect(response.status).to eq(200)
      expect(response.parsed_body.dig("result", "isError")).to eq(true)
    end

    expect(staged_user.reload).to be_staged
    expect(User.find_by_username("blank_password")).to be_nil
  end

  it "preserves surrounding whitespace in a nonblank password" do
    authorize("mcp:users:write")
    password = "  correct horse battery staple  "

    call_tool(
      "discourse_create_user",
      {
        username: "spaced_password",
        email: "spaced@example.com",
        name: "Spaced",
        password: password,
      },
    )

    expect(response.status).to eq(200)
    expect(structured_content["created"]).to eq(true)
    created_user = User.find_by_username("spaced_password")
    expect(created_user.confirm_password?(password)).to eq(true)
    expect(created_user.confirm_password?(password.strip)).to eq(false)
  end

  it "approves an explicitly unapproved account when signup approval is disabled" do
    SiteSetting.must_approve_users = false
    SiteSetting.invite_only = false
    authorize("mcp:users:write")
    call_tool(
      "discourse_create_user",
      {
        username: "manual_approval",
        email: "manual-approval@example.com",
        name: "Manual Approval",
        password: "correct horse battery staple",
        approved: false,
      },
    )
    created_user = User.find_by_username("manual_approval")
    expect(created_user).to be_active
    expect(created_user).not_to be_approved
    expect(ReviewableUser.find_by(target: created_user)).to be_nil

    call_tool(
      "discourse_manage_user_activation",
      { username: created_user.username, action: "approve", confirm: true },
    )

    expect(response.status).to eq(200)
    expect(structured_content["approved"]).to eq(true)
    expect(created_user.reload).to be_approved
    expect(ReviewableUser.find_by(target: created_user)).to be_approved
    expect(
      UserHistory.where(
        action: UserHistory.actions[:approve_user],
        target_user_id: created_user.id,
      ).count,
    ).to eq(1)
  end

  it "requires both scope and staff authority for approval without a reviewable" do
    SiteSetting.must_approve_users = false
    SiteSetting.invite_only = false
    pending_user = Fabricate(:user, active: true, approved: false)

    [[admin, []], [user, ["mcp:users:write"]]].each do |actor, scopes|
      authorize(*scopes, auth_user: actor)

      call_tool(
        "discourse_manage_user_activation",
        { username: pending_user.username, action: "approve", confirm: true },
      )

      expect(response.status).to eq(403)
      expect(pending_user.reload).not_to be_approved
      expect(ReviewableUser.find_by(target: pending_user)).to be_nil
      expect(
        UserHistory.where(
          action: UserHistory.actions[:approve_user],
          target_user_id: pending_user.id,
        ),
      ).not_to exist
    end
  end

  it "omits submitted values from user creation schema errors" do
    authorize("mcp:users:write")
    arguments = {
      username: "invalid_signup",
      email: "invalid-signup@example.com",
      name: "Invalid Signup",
      password: "correct horse battery staple",
    }

    [arguments.except(:name), arguments.merge(password: "secret" * 40)].each do |invalid_arguments|
      call_tool("discourse_create_user", invalid_arguments)

      expect(response.status).to eq(400)
      expect(response.parsed_body.dig("error", "code")).to eq(-32_602)
      errors = response.parsed_body.dig("error", "data", "errors")
      expect(errors).to be_present
      errors.each do |error|
        expect(error.keys).to contain_exactly("type", "data_pointer", "schema_pointer")
      end
      expect(response.body).not_to include(invalid_arguments[:password])
    end

    expect(User.find_by_username(arguments[:username])).to be_nil
  end

  it "converts an existing staged user with a mixed-case email" do
    staged_user = Fabricate(:staged, email: "staged-review@example.com")
    authorize("mcp:users:write")

    expect do
      call_tool(
        "discourse_create_user",
        {
          username: "converted_cat",
          email: "Staged-Review@Example.com",
          name: "Converted Cat",
          password: "correct horse battery staple",
        },
      )
    end.not_to change(User, :count)

    expect(response.status).to eq(200)
    expect(structured_content).to include("created" => true, "user_id" => staged_user.id)
    expect(staged_user.reload).not_to be_staged
    expect(staged_user).to be_active.and be_approved
    expect(staged_user.email).to eq("staged-review@example.com")
  end

  it "does not let a moderator create users when the token has write scope" do
    authorize("mcp:users:write", auth_user: moderator)

    call_tool(
      "discourse_create_user",
      {
        username: "not_created",
        email: "not-created@example.com",
        name: "Not Created",
        password: "correct horse battery staple",
      },
    )

    expect(response.status).to eq(403)
    expect(User.find_by_username("not_created")).to be_nil
  end

  it "lets staff activate and approve an eligible user" do
    SiteSetting.must_approve_users = true
    inactive_user = Fabricate(:inactive_user, approved: false)
    authorize("mcp:users:write", auth_user: moderator)

    call_tool(
      "discourse_manage_user_activation",
      { username: inactive_user.username, action: "activate_and_approve", confirm: true },
    )

    expect(response.status).to eq(200)
    expect(inactive_user.reload).to be_active.and be_approved
    expect(structured_content).to include(
      "username" => inactive_user.username,
      "requested_action" => "activate_and_approve",
      "completed_actions" => %w[activate approve],
      "active" => true,
      "approved" => true,
    )
  end

  it "requires confirmation and preserves the target when access is denied" do
    authorize("mcp:users:write", auth_user: moderator)

    call_tool("discourse_manage_user_activation", { username: user.username, action: "deactivate" })
    expect(response.status).to eq(400)
    expect(user.reload).to be_active

    call_tool(
      "discourse_manage_user_activation",
      { username: admin.username, action: "deactivate", confirm: true },
    )
    expect(response.status).to eq(403)
    expect(admin.reload).to be_active
  end
end
