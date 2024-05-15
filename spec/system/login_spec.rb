# frozen_string_literal: true

describe "Login", type: :system do
  let(:login_modal) { PageObjects::Modals::Login.new }
  fab!(:user) { Fabricate(:user, username: "john", password: "supersecurepassword") }

  context "with username and password" do
    it "can login" do
      EmailToken.confirm(Fabricate(:email_token, user: user).token)

      login_modal.open
      login_modal.fill_username("john")
      login_modal.fill_password("supersecurepassword")
      login_modal.confirm_login
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can login and activate account" do
      Jobs.run_immediately!

      login_modal.open
      login_modal.fill_username("john")
      login_modal.fill_password("supersecurepassword")
      login_modal.confirm_login

      find(".activation-controls button.resend").click

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}, 0]

      visit activation_link
      find("#activate-account-button").click

      visit "/"
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    it "can reset password" do
      Jobs.run_immediately!

      login_modal.open
      login_modal.fill_username("john")
      login_modal.forgot_password
      find("button.forgot-password-reset").click

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)
      reset_password_link = mail.body.to_s[%r{/u/password-reset/\S+}, 0]
      visit reset_password_link

      find("#new-account-password").fill_in(with: "newsuperpassword")
      find("form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with login link" do
    it "can login" do
      Jobs.run_immediately!

      login_modal.open
      login_modal.fill_username("john")
      login_modal.email_login_link

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(user.email)

      login_link = mail.body.to_s[%r{/session/email-login/\S+}, 0]
      visit login_link

      find(".email-login-form .btn-primary").click
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  context "with passkey" do
    it "can login" do
      # TODO: move existing tests here (?)
    end
  end

  context "when site is login required" do
    it "can login" do
      # TODO: add test
    end
  end
end
