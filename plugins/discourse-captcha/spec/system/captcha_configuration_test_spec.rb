# frozen_string_literal: true

describe "CAPTCHA admin configuration" do
  fab!(:admin)

  it "labels the v2 key settings explicitly" do
    SiteSetting.discourse_captcha_enabled = true
    sign_in(admin)

    visit "/admin/site_settings/category/discourse_captcha"

    expect(page).to have_css(
      '[data-setting="recaptcha_v2_site_key"] .setting-label',
      text: "Recaptcha v2 site key",
    )
    expect(page).to have_css(
      '[data-setting="recaptcha_v2_secret_key"] .setting-label',
      text: "Recaptcha v2 secret key",
    )
  end
end
