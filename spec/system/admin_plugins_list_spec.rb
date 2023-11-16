# frozen_string_literal: true

describe "Admin Plugins List", type: :system, js: true do
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  let(:spoiler_alert_plugin) do
    plugins = Plugin::Instance.find_all("#{Rails.root}/plugins")
    plugins.find { |p| p.name == "spoiler-alert" }
  end

  xit "shows the list of plugins" do
    visit "/admin/plugins"

    plugin_row = find(".admin-plugins tr[data-plugin-name=\"spoiler-alert\"]")
    expect(plugin_row).to have_css(
      "td.plugin-details .name-with-badges .name",
      text: "Spoiler Alert",
    )
    expect(plugin_row).to have_css(
      "td.plugin-details .author",
      text: I18n.t("admin_js.admin.plugins.author", { author: "Discourse" }),
    )
    expect(plugin_row).to have_css(
      "td.plugin-details .name-with-badges .name a[href=\"https://meta.discourse.org/t/12650\"]",
    )
    expect(plugin_row).to have_css(
      "td.plugin-details .about",
      text: spoiler_alert_plugin.metadata.about,
    )
  end
end
