# frozen_string_literal: true

require "rotp"

shared_examples "login scenarios" do
  let(:login_modal) { PageObjects::Modals::Login.new }
  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }

  before { Jobs.run_immediately! }

  context "with username and password" do
    it "can login" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      login_modal.open
      login_modal.fill(username: "john", password: "supersecurepassword")
      login_modal.click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login and activate account" do
      login_modal.open
      login_modal.fill(username: "john", password: "supersecurepassword")
      login_modal.click_login
      expect(page).to have_css(".not-activated-modal")
      login_modal.click(".activation-controls button.resend")

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]
      visit activation_link

      find("#activate-account-button").click

      visit "/"
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can reset password" do
      login_modal.open
      login_modal.fill_username("john")
      login_modal.forgot_password
      find("button.forgot-password-reset").click

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      reset_password_link = mail.body.to_s[%r{/u/password-reset/\S+}]
      visit reset_password_link

      find("#new-account-password").fill_in(with: "newsuperpassword")
      find("form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with login link" do
    it "can login" do
      login_modal.open
      login_modal.fill_username("john")
      login_modal.email_login_link

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      login_link = mail.body.to_s[%r{/session/email-login/\S+}]
      visit login_link

      find(".email-login-form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with two-factor authentication" do
    let!(:user_second_factor) { Fabricate(:user_second_factor_totp, user: user) }
    let!(:user_second_factor_backup) { Fabricate(:user_second_factor_backup, user: user) }
    fab!(:other_user) { Fabricate(:user, username: "jane", password: "supersecurepassword") }

    before do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)
      EmailToken.confirm(Fabricate(:email_token, user: other_user).token)
    end

    context "when it is required" do
      before { SiteSetting.enforce_second_factor = "all" }

      it "requires to set 2FA after login" do
        login_modal.open
        login_modal.fill(username: "jane", password: "supersecurepassword")
        login_modal.click_login
        expect(page).to have_css(".header-dropdown-toggle.current-user")
        expect(page).to have_content(I18n.t("js.user.second_factor.enforced_notice"))
      end
    end

    it "can login with totp" do
      login_modal.open
      login_modal.fill(username: "john", password: "supersecurepassword")
      login_modal.click_login
      expect(page).to have_css(".login-modal-body.second-factor")

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find("#login-second-factor").fill_in(with: totp)
      login_modal.click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with backup code" do
      login_modal.open
      login_modal.fill(username: "john", password: "supersecurepassword")
      login_modal.click_login
      expect(page).to have_css(".login-modal-body.second-factor")

      find(".toggle-second-factor-method").click
      find(".second-factor-token-input").fill_in(with: "iAmValidBackupCode")
      login_modal.click_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with login link and totp" do
      login_modal.open
      login_modal.fill_username("john")
      login_modal.email_login_link

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      login_link = mail.body.to_s[%r{/session/email-login/\S+}]
      visit login_link

      totp = ROTP::TOTP.new(user_second_factor.data).now
      find(".second-factor-token-input").fill_in(with: totp)
      find(".email-login-form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login with login link and backup code" do
      login_modal.open
      login_modal.fill_username("john")
      login_modal.email_login_link

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      login_link = mail.body.to_s[%r{/session/email-login/\S+}]
      visit login_link

      find(".toggle-second-factor-method").click
      find(".second-factor-token-input").fill_in(with: "iAmValidBackupCode")
      find(".email-login-form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end
end

describe "Login", type: :system do
  context "when desktop" do
    include_examples "login scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "login scenarios"
  end
end
