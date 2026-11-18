# frozen_string_literal: true

describe "User slow mode" do
  fab!(:moderator)
  fab!(:user)

  it "lets moderators set and remove a posting interval from the user's admin page" do
    SiteSetting.enable_user_slow_mode = true
    sign_in(moderator)
    PageObjects::Pages::AdminUser.new.visit(user)

    find("button.user-slow-mode", text: I18n.t("admin_js.admin.user.slow_mode.set")).click
    within(".user-slow-mode-modal") do
      fill_in I18n.t("admin_js.admin.user.slow_mode.minutes"), with: 5
      click_button I18n.t("js.save")
    end

    expect(page).to have_no_css(".user-slow-mode-modal")
    expect(user.reload.user_slow_mode_seconds).to eq(300)

    find("button.user-slow-mode", text: I18n.t("admin_js.admin.user.slow_mode.change")).click
    within(".user-slow-mode-modal") { click_button I18n.t("admin_js.admin.user.slow_mode.remove") }

    expect(page).to have_no_css(".user-slow-mode-modal")
    expect(user.reload.user_slow_mode_seconds).to eq(0)
  end
end
