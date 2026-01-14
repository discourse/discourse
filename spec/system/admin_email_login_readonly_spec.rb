# frozen_string_literal: true

describe "Admin email login in readonly mode", type: :system do
  fab!(:admin)

  context "when site is in readonly mode" do
    before { Discourse.enable_readonly_mode }

    it "allows admin to request email login from /u/admin-login page" do
      Jobs.run_immediately!
      ActionMailer::Base.deliveries.clear

      page.visit "/u/admin-login"

      fill_in "email", with: admin.email
      click_button "Send Email"

      expect(page).to have_content(I18n.t("admin_login.acknowledgement", email: admin.email))

      expect(ActionMailer::Base.deliveries.count).to eq(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(admin.email)
      expect(mail.body.to_s).to include("/session/email-login/")
    end

    it "allows admin to login via email token during readonly mode" do
      email_token =
        admin.email_tokens.create!(email: admin.email, scope: EmailToken.scopes[:email_login])

      page.visit "/session/email-login/#{email_token.token}"

      find(".email-login-form .btn-primary").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
      expect(page).to have_content(admin.username)
    end
  end
end
