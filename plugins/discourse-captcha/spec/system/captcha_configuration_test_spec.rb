# frozen_string_literal: true

describe "CAPTCHA admin configuration" do
  fab!(:admin)

  it "labels the v2 key settings explicitly" do
    SiteSetting.discourse_captcha_enabled = true
    sign_in(admin)

    visit "/admin/plugins/discourse-captcha/settings"

    expect(page).to have_css(
      '[data-setting="recaptcha_v2_site_key"] .setting-label',
      text: "Recaptcha v2 site key",
    )
    expect(page).to have_css(
      '[data-setting="recaptcha_v2_secret_key"] .setting-label',
      text: "Recaptcha v2 secret key",
    )
  end

  it "reports working keys and a low score without asking the admin to solve a challenge" do
    SiteSetting.discourse_captcha_enabled = true
    SiteSetting.discourse_captcha_provider = "recaptcha_v3"
    SiteSetting.recaptcha_v3_site_key = "v3-site-key"
    SiteSetting.recaptcha_v3_secret_key = "v3-secret-key"
    SiteSetting.recaptcha_v3_score_threshold = 0.5
    sign_in(admin)

    page.driver.with_playwright_page { |pw_page| pw_page.add_init_script(script: <<~JS) }
      window.grecaptcha = {
        execute: (siteKey, { action }) => {
          if (siteKey !== "v3-site-key" || action !== "configuration_test") {
            return Promise.reject(new Error("Unexpected test configuration"));
          }
          return Promise.resolve("admin-test-token");
        }
      };
    JS

    stub_request(:post, "https://www.google.com/recaptcha/api/siteverify").with(
      body: {
        secret: "v3-secret-key",
        response: "admin-test-token",
      },
    ).to_return(
      status: 200,
      body: { success: true, action: "configuration_test", score: 0.1 }.to_json,
    )

    visit "/admin/plugins/discourse-captcha/test"
    find(".captcha-configuration-test .btn-primary").click

    expect(page).to have_css(
      ".captcha-configuration-test .alert-success",
      text: I18n.t("discourse_captcha.configuration_test.v3_low_score", score: 0.1, threshold: 0.5),
    )
    expect(page).to have_no_text(
      I18n.t("js.discourse_captcha.configuration_test.complete_challenge"),
    )
  end
end
