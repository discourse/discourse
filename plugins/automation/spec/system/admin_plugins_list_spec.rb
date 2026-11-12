# frozen_string_literal: true

# NOTE: This spec covers core functionality, but it is much easier
# to test plugin related things inside an actual plugin.
describe "Admin Plugins List" do
  fab!(:current_user, :admin)
  let(:admin_plugins_list_page) { PageObjects::Pages::AdminPluginsList.new }

  before do
    sign_in(current_user)
    SiteSetting.discourse_automation_enabled = true
  end

  let(:automation_plugin) do
    Plugin::Instance.parse_from_source(Rails.root.join("plugins/automation/plugin.rb").to_s)
  end

  it "shows the list of plugins" do
    admin_plugins_list_page.visit

    expect(admin_plugins_list_page.find_plugin("automation")).to have_css(
      ".admin-plugins-list__name-with-badges .admin-plugins-list__name",
      text: "Automation",
    )
    expect(admin_plugins_list_page.find_plugin("automation")).to have_css(
      ".admin-plugins-list__author",
      text: I18n.t("admin_js.admin.plugins.author", { author: "Discourse" }),
    )
    expect(admin_plugins_list_page.find_plugin("automation")).to have_css(
      ".admin-plugins-list__about",
      text: automation_plugin.metadata.about,
    )
  end

  it "can toggle whether a plugin is enabled" do
    admin_plugins_list_page.visit

    admin_plugins_list_page.toggle_plugin("automation")
    expect(admin_plugins_list_page).to have_plugin_disabled("automation")
    expect(SiteSetting.discourse_automation_enabled).to eq(false)

    admin_plugins_list_page.toggle_plugin("automation")
    expect(admin_plugins_list_page).to have_plugin_enabled("automation")
    expect(SiteSetting.discourse_automation_enabled).to eq(true)
  end

  it "links a plugin with a config page to its config page" do
    admin_plugins_list_page.visit
    admin_plugins_list_page.click_plugin_name("automation")

    expect(page).to have_css(".admin-plugin-config-page .d-page-header__title", text: "Automation")
  end
end
