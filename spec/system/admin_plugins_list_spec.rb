# frozen_string_literal: true

describe "Admin Plugins List", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:admin_plugins_list_page) { PageObjects::Pages::AdminPluginsList.new }

  before do
    sign_in(current_user)
    Discourse.stubs(:visible_plugins).returns([spoiler_alert_plugin])
  end

  let(:spoiler_alert_plugin) do
    parsed_plugin =
      Plugin::Instance.parse_from_source(
        File.join(Rails.root, "plugins", "spoiler-alert", "plugin.rb"),
      )
    parsed_plugin.enabled_site_setting(:spoiler_enabled)
    parsed_plugin
  end

  it "shows the list of plugins" do
    admin_plugins_list_page.visit

    expect(admin_plugins_list_page.find_plugin("spoiler-alert")).to have_css(
      ".admin-plugins-list__name-with-badges .admin-plugins-list__name",
      text: "Spoiler Alert",
    )
    expect(admin_plugins_list_page.find_plugin("spoiler-alert")).to have_css(
      ".admin-plugins-list__author",
      text: I18n.t("admin_js.admin.plugins.author", { author: "Discourse" }),
    )
    expect(admin_plugins_list_page.find_plugin("spoiler-alert")).to have_css(
      ".admin-plugins-list__about",
      text: spoiler_alert_plugin.metadata.about,
    )
  end

  it "can toggle whether a plugin is enabled" do
    admin_plugins_list_page.visit
    toggle_switch =
      PageObjects::Components::DToggleSwitch.new(
        admin_plugins_list_page.plugin_row_selector("spoiler-alert") +
          " .admin-plugins-list__enabled .d-toggle-switch",
      )
    toggle_switch.toggle
    expect(toggle_switch).to be_unchecked
    expect(SiteSetting.spoiler_enabled).to eq(false)
    toggle_switch.toggle
    expect(toggle_switch).to be_checked
    expect(SiteSetting.spoiler_enabled).to eq(true)
  end

  it "shows a navigation tab for each plugin that needs it" do
    spoiler_alert_plugin.add_admin_route("spoiler.title", "index")
    admin_plugins_list_page.visit
    expect(admin_plugins_list_page).to have_plugin_tab("spoiler-alert")
  end
end
