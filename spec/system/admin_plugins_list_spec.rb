# frozen_string_literal: true

describe "Admin Plugins List", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }
  let(:admin_plugins_list_page) { PageObjects::Pages::AdminPluginsList.new }

  before do
    sign_in(current_user)
    Discourse.stubs(:visible_plugins).returns([spoiler_alert_plugin])
  end

  let(:spoiler_alert_plugin) do
    path = File.join(Rails.root, "plugins", "spoiler-alert", "plugin.rb")
    Plugin::Instance.parse_from_source(path)
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
  end
end
