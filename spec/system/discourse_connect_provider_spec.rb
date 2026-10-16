# frozen_string_literal: true
require "rotp"

describe "Discourse Connect Provider" do
  include DiscourseConnectHelpers

  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let(:sso_port) { setup_test_discourse_connect_server(user:, sso_secret:) }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
  let(:login_form) { PageObjects::Pages::Login.new }
  let!(:return_url) { "http://localhost:#{sso_port}/test/url" }

  before do
    SiteSetting.enable_discourse_connect_provider = true
    SiteSetting.discourse_connect_provider_secrets = "localhost|Test"
    SiteSetting.enable_discourse_connect = false
    Jobs.run_immediately!
  end

  it "redirects back to the return_sso_url after successful login" do
    sso, sig = build_discourse_connect_payload(return_url)
    EmailToken.confirm(Fabricate(:email_token, user: user).token)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_page
      .goto("/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_page).to have_url("/login")

    login_form.fill(username: "john", password: "supersecurepassword").click_login

    expect(browser_page).to have_url(/#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/)
  end

  it "lets a new account pick a username before returning to the return_sso_url" do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    new_email = "new.person@example.com"
    sso, sig = build_discourse_connect_payload(return_url)

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_page
      .goto("/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(browser_page).to have_url("/login")
    expect(browser_root.locator("#login-account-name").filter(visible: true)).not_to have_count(0)

    browser_root.locator("#one-time-code-link").filter(visible: true).click
    browser_root
      .locator(".code-login-form__email-step input[type='email']")
      .filter(visible: true)
      .fill(new_email)
    browser_root.locator(".code-login-form__continue").filter(visible: true).click

    wait_for(timeout: 10) { ActionMailer::Base.deliveries.present? }
    browser_root
      .locator(".d-otp-input")
      .filter(visible: true)
      .fill(ActionMailer::Base.deliveries.last.subject[/(\d{6})/, 1])

    # The handoff waits here rather than redirecting as soon as the session
    # exists, so the generated placeholder username can be replaced.
    expect(
      browser_root.locator(".code-login-form__signup-details-step").filter(visible: true),
    ).not_to have_count(0)
    browser_root.locator("#code-login-username").filter(visible: true).fill("janedoe")
    expect(
      browser_root.locator(".code-login-form__continue-to-site[disabled]").filter(visible: true),
    ).to have_count(0)
    browser_root.locator(".code-login-form__continue-to-site").filter(visible: true).click

    expect(browser_page).to have_url(/#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/)
    expect(User.find_by_email(new_email).username).to eq("janedoe")
  end

  context "with two-factor authentication" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
    let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }

    fab!(:other_user) { Fabricate(:user, username: "jane", password: "supersecurepassword") }

    it "redirects back to the return_sso_url" do
      sso, sig = build_discourse_connect_payload(return_url)
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_page
        .goto("/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(browser_page).to have_url("/login")

      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(browser_root.locator(".second-factor").filter(visible: true)).not_to have_count(0)

      totp = ROTP::TOTP.new(user_second_factor.data).now
      browser_root.locator("#login-second-factor").filter(visible: true).fill(totp)

      expect(browser_page).to have_url(/#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/)
    end
  end
end
