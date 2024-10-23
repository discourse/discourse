# frozen_string_literal: true

# NOTE: This spec covers core functionality, but it is much easier
# to test plugin related things inside an actual plugin.
describe "Admin Plugins List", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:admin_plugins_list_page) { PageObjects::Pages::AdminPluginsList.new }

  before do
    sign_in(current_user)
    SiteSetting.discourse_automation_enabled = true
  end

  let(:automation_plugin) do
    Plugin::Instance.parse_from_source(File.join(Rails.root, "plugins", "automation", "plugin.rb"))
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
    toggle_switch =
      PageObjects::Components::DToggleSwitch.new(
        admin_plugins_list_page.plugin_row_selector("automation") +
          " .admin-plugins-list__enabled .d-toggle-switch__checkbox",
      )
    expect(toggle_switch).to be_checked
    toggle_switch.toggle
    expect(toggle_switch).to be_unchecked
    expect(SiteSetting.discourse_automation_enabled).to eq(false)
    toggle_switch.toggle
    expect(toggle_switch).to be_checked
    expect(SiteSetting.discourse_automation_enabled).to eq(true)
  end

  it "shows a navigation tab for each plugin that needs it" do
    admin_plugins_list_page.visit
    expect(admin_plugins_list_page).to have_plugin_tab("automation")
  end
end
