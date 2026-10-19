# frozen_string_literal: true

describe "Admin email login in readonly mode" do
  fab!(:admin)

  context "when site is in readonly mode" do
    before { Discourse.enable_readonly_mode }

    it "allows admin to request email login from /u/admin-login page" do
      Jobs.run_immediately!
      ActionMailer::Base.deliveries.clear

      browser_page.goto("/u/admin-login").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root
        .locator("input:not(:disabled), textarea:not(:disabled), select:not(:disabled)")
        .and(
          browser_root.locator("[id=#{"email".to_s.to_json}], [name=#{"email".to_s.to_json}]").or(
            browser_root.get_by_label("email", exact: true),
          ),
        )
        .filter(visible: true)
        .fill(admin.email)
      browser_root
        .locator("[id=#{"Send Email".to_s.to_json}], [name=#{"Send Email".to_s.to_json}]")
        .or(browser_root.get_by_role("button", name: "Send Email"))
        .filter(visible: true)
        .click

      expect(browser_content).to contain_text(
        browser_text_pattern(I18n.t("admin_login.acknowledgement", email: admin.email)),
        useInnerText: true,
      )

      expect(ActionMailer::Base.deliveries.count).to eq(1)

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly(admin.email)
      expect(mail.body.to_s).to include("/session/email-login/")
    end

    it "allows admin to login via email token during readonly mode" do
      email_token =
        admin.email_tokens.create!(email: admin.email, scope: EmailToken.scopes[:email_login])

      browser_page
        .goto("/session/email-login/#{email_token.token}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root.locator(".email-login-form .btn-primary").filter(visible: true).click

      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to have_count(0)
      expect(browser_content).to contain_text(
        browser_text_pattern(admin.username),
        useInnerText: true,
      )
    end
  end
end
