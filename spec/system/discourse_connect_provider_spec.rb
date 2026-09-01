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

    visit "/"
    visit "/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}"
    expect(page).to have_current_path("/login")

    login_form.fill(username: "john", password: "supersecurepassword").click_login

    expect(page).to have_current_path(
      /#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/,
      url: true,
      ignore_query: false,
    )
  end

  it "lets a new account pick a username before returning to the return_sso_url" do
    SiteSetting.enable_local_logins_via_email = true
    SiteSetting.enable_local_logins_via_code = true
    new_email = "new.person@example.com"
    sso, sig = build_discourse_connect_payload(return_url)

    visit "/"
    visit "/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}"
    expect(page).to have_current_path("/login")
    expect(page).to have_css("#login-account-name")

    find("#one-time-code-link").click
    find(".code-login-form__email-step input[type='email']").fill_in(with: new_email)
    find(".code-login-form__continue").click

    wait_for(timeout: 10) { ActionMailer::Base.deliveries.present? }
    find(".d-otp-input").fill_in(with: ActionMailer::Base.deliveries.last.subject[/(\d{6})/, 1])

    # The handoff waits here rather than redirecting as soon as the session
    # exists, so the generated placeholder username can be replaced.
    expect(page).to have_css(".code-login-form__complete-step")
    find("#code-login-username").fill_in(with: "janedoe")
    expect(page).to have_no_css(".code-login-form__continue-to-site[disabled]")
    find(".code-login-form__continue-to-site").click

    expect(page).to have_current_path(
      /#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/,
      url: true,
      ignore_query: false,
    )
    expect(User.find_by_email(new_email).username).to eq("janedoe")
  end

  context "with two-factor authentication" do
    before do
      Fabricate(:user_second_factor_totp, user: user)
      Fabricate(:user_second_factor_backup, user: user)
    end

    fab!(:other_user) { Fabricate(:user, username: "jane", password: "supersecurepassword") }

    it "redirects back to the return_sso_url" do
      sso, sig = build_discourse_connect_payload(return_url)
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      visit "/"
      visit "/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}"
      expect(page).to have_current_path("/login")

      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(page).to have_css(".second-factor")

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find("#login-second-factor").fill_in(with: totp)

      expect(page).to have_current_path(
        /#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/,
        url: true,
        ignore_query: false,
      )
    end
  end
end
