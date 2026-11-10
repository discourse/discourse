# frozen_string_literal: true

RSpec.describe "Live admin navigation" do
  fab!(:admin)

  before do
    SiteSetting.live_enabled = true
    sign_in(admin)
  end

  it "highlights only the current configuration tab" do
    visit("/admin/plugins/live/settings")

    tabs = ".admin-plugin-config-page__top-nav-item"
    expect(page).to have_css(tabs, count: 4)
    expect(page).to have_css("#{tabs}.active", count: 1)
    expect(page).to have_css(
      "#{tabs}.active",
      text: I18n.t("admin_js.admin.plugins.change_settings_short"),
    )

    %w[dashboard_title rooms_title recordings_title].each do |label|
      title = I18n.t("js.live.admin.#{label}")
      find(tabs, text: title, exact_text: true).click

      expect(page).to have_css("#{tabs}.active", count: 1)
      expect(page).to have_css("#{tabs}.active", text: title)
    end

    find(tabs, text: I18n.t("admin_js.admin.plugins.change_settings_short"), exact_text: true).click
    expect(page).to have_css("#{tabs}.active", count: 1)
    expect(page).to have_css(
      "#{tabs}.active",
      text: I18n.t("admin_js.admin.plugins.change_settings_short"),
    )
  end
end
