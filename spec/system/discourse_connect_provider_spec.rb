# frozen_string_literal: true
require "rotp"

describe "Discourse Connect Provider", type: :system do
  include SsoHelpers

  let(:sso_secret) { SecureRandom.alphanumeric(32) }
  let(:sso_port) { 9876 }
  let(:sso_url) { "http://localhost:#{sso_port}/sso" }

  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }
  let(:login_form) { PageObjects::Pages::Login.new }
  let!(:return_url) { "http://localhost:#{sso_port}/test/url" }
  before do
    SiteSetting.enable_discourse_connect_provider = true
    SiteSetting.discourse_connect_provider_secrets = "localhost|Test"
    SiteSetting.enable_discourse_connect = false
    Jobs.run_immediately!

    setup_test_sso_server(user: user, sso_secret:, sso_port:, sso_url:)
  end

  after { shutdown_test_sso_server }

  it "redirects back to the return_sso_url after successful login" do
    sso, sig = build_sso_payload(return_url)
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
  context "with two-factor authentication" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
    let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }
    fab!(:other_user) { Fabricate(:user, username: "jane", password: "supersecurepassword") }

    it "redirects back to the return_sso_url" do
      sso, sig = build_sso_payload(return_url)
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      visit "/"
      visit "/session/sso_provider?sso=#{CGI.escape(sso)}&sig=#{sig}"
      expect(page).to have_current_path("/login")

      login_form.fill(username: "john", password: "supersecurepassword").click_login

      expect(page).to have_css(".second-factor")

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find("#login-second-factor").fill_in(with: totp)
      login_form.click_login

      expect(page).to have_current_path(
        /#{Regexp.escape(return_url)}\?sso=.*&sig=[0-9a-f]+/,
        url: true,
        ignore_query: false,
      )
    end
  end
end
