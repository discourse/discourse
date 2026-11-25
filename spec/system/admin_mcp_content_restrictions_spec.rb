# frozen_string_literal: true

describe "Admin MCP content restrictions page" do
  fab!(:admin)
  fab!(:tag) { Fabricate(:tag, name: "legal-hold") }

  let(:restrictions_page) { PageObjects::Pages::AdminMcpContentRestrictions.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    SiteSetting.mcp_server_enabled = true
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "switches personal message access off after confirmation and back on" do
    # Every active rule switches off tools that can send content off-site.
    McpPrimitive.create!(kind: "tool", identifier: "discourse_update_site_setting", enabled: true)

    restrictions_page.visit_page
    expect(restrictions_page).to have_private_messages_access(true)

    restrictions_page.toggle_private_messages
    expect(dialog).to be_open
    expect(dialog).to have_content("Update site setting")
    dialog.click_yes

    expect(restrictions_page).to have_private_messages_access(false)
    expect(McpContentRule.exists?(rule_kind: "private_messages")).to eq(true)
    screenshot_marker(label: "mcp-content-restrictions-pm-off")

    restrictions_page.toggle_private_messages

    expect(restrictions_page).to have_private_messages_access(true)
    expect(McpContentRule.exists?(rule_kind: "private_messages")).to eq(false)
  end

  it "saves a denied tag and turns the topics and posts rule off again" do
    restrictions_page.visit_page
    restrictions_page.deny_tag(tag.name).save_forum_rule

    expect(restrictions_page).to have_forum_rule_active
    rule = McpContentRule.find_by!(rule_kind: "forum_content")
    expect(rule.config.dig("deny", "tag_ids")).to eq([tag.id])
    expect(rule.updated_by).to eq(admin)

    page.refresh
    expect(page).to have_css(
      ".--forum-content .form-kit__field[data-name='deny_tags']",
      text: tag.name,
    )
    screenshot_marker(label: "mcp-content-restrictions-forum-active")

    restrictions_page.turn_off_forum_rule

    expect(restrictions_page).to have_no_forum_rule_active
    expect(McpContentRule.exists?(rule_kind: "forum_content")).to eq(false)
  end

  it "lets an admin delete a stored rule whose kind is no longer known" do
    McpContentRule.create!(rule_kind: "gone:rule", config: {})

    restrictions_page.visit_page
    expect(restrictions_page).to have_unknown_rule("gone:rule")
    screenshot_marker(label: "mcp-content-restrictions-unknown-rule")

    restrictions_page.delete_unknown_rule("gone:rule")

    expect(restrictions_page).to have_no_unknown_rule("gone:rule")
    expect(McpContentRule.exists?(rule_kind: "gone:rule")).to eq(false)
  end
end
