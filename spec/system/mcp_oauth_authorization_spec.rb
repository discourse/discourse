# frozen_string_literal: true

describe "MCP OAuth authorization" do
  include ThemeScreenshotMarker

  fab!(:admin)
  fab!(:user)

  let(:authorization_page) { PageObjects::Pages::McpOauthAuthorization.new }

  def create_client(redirect_uri)
    McpOauthClient.create!(
      client_id: "acme-assistant",
      name: "Acme Assistant",
      registration_type: "pre_registered",
      trust_state: "approved",
      redirect_uris: [redirect_uri],
    )
  end

  before do
    SiteSetting.mcp_server_enabled = true
    McpGroupScope.ensure_admins!
  end

  it "shows an admin what the app could do, split by how much it affects the site" do
    client = create_client("https://assistant.example.com/oauth/callback")
    sign_in(admin)

    authorization_page.visit(
      client:,
      scopes: %w[
        mcp:profile:read
        mcp:content:read
        mcp:content:write
        mcp:categories:read
        mcp:categories:write
        mcp:site-settings:read
        mcp:site-settings:write
        mcp:themes:read
        mcp:themes:write
      ],
    )

    expect(authorization_page).to have_section(I18n.t("mcp.oauth.scope_sections.member"))
    expect(authorization_page).to have_section(I18n.t("mcp.oauth.scope_sections.manage"))
    expect(authorization_page).to have_permission(I18n.t("mcp.oauth.scopes.mcp_content_write"))
    expect(authorization_page).to have_permission(
      I18n.t("mcp.oauth.scopes.mcp_site_settings_write"),
    )
    expect(authorization_page).to have_redirect_notice("assistant.example.com")
    screenshot_marker(label: "mcp-authorize")
  end

  it "lets an admin authorize an app on their device" do
    client = create_client("#{Discourse.base_url}/mcp-callback")
    sign_in(admin)

    authorization_page.visit(client:, scopes: %w[mcp:profile:read mcp:content:read])

    local_host = URI(Discourse.base_url).then { |uri| "#{uri.host}:#{uri.port}" }
    expect(authorization_page).to have_redirect_notice(
      I18n.t("mcp.oauth.redirect_local_html", host: local_host),
    )
    screenshot_marker(label: "mcp-authorize-local")

    authorization_page.click_authorize

    expect(page).to have_current_path(%r{\A/mcp-callback\?code=})
    expect(McpOauthAuthorization.find_by(user: admin, client:).scopes).to contain_exactly(
      "mcp:profile:read",
      "mcp:content:read",
    )
  end

  it "tells a member which permissions the app won't get, and lets them cancel" do
    client = create_client("#{Discourse.base_url}/mcp-callback")
    group = Fabricate(:group)
    group.add(user)
    McpGroupScope.create!(group:, scope: "mcp:profile:read")
    McpGroupScope.create!(group:, scope: "mcp:content:read")
    sign_in(user)

    authorization_page.visit(
      client:,
      scopes: %w[mcp:profile:read mcp:content:read mcp:content:write mcp:site-settings:write],
    )
    authorization_page.show_withheld_permissions

    expect(authorization_page).to have_permission(I18n.t("mcp.oauth.scopes.mcp_content_read"))
    expect(authorization_page).to have_withheld_permission(
      I18n.t("mcp.oauth.scopes.mcp_site_settings_write"),
    )
    screenshot_marker(label: "mcp-authorize-partial")

    authorization_page.click_cancel

    expect(page).to have_current_path(%r{\A/mcp-callback\?error=access_denied})
    expect(McpOauthAuthorization.where(user:)).to be_empty
  end
end
