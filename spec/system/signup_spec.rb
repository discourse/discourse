# frozen_string_literal: true

shared_examples "signup scenarios" do
  let(:signup_page) { PageObjects::Pages::Signup.new }
  let(:login_page) { PageObjects::Pages::Login.new }
  let(:invite_form) { PageObjects::Pages::InviteForm.new }
  let(:activate_account) { PageObjects::Pages::ActivateAccount.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:invite) { Fabricate(:invite) }
  let(:topic) { Fabricate(:topic, title: "Super cool topic") }

  # These cover the password signup form. The code-based form replaces it when
  # enable_local_logins_via_code is on, and has its own spec.
  before { SiteSetting.enable_local_logins_via_code = false }

  context "when anyone can create an account" do
    before { Jobs.run_immediately! }

    it "can sign up, activate the account, and access 2FA preferences" do
      signup_page
        .open
        .fill_email(invite.email)
        .fill_username("john")
        .fill_password("supersecurepassword")
      expect(signup_page).to have_valid_fields

      screenshot_marker(label: "signup")

      signup_page.click_create_account
      expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to contain_exactly(invite.email)
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]

      browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      screenshot_marker(label: "signup-activation")

      activate_account.click_activate_account
      activate_account.click_continue

      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)

      browser_page
        .goto("/u/john/preferences/security")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root.locator(".btn-second-factor").filter(visible: true).click

      expect(
        browser_root.locator(".user-preferences.second-factor").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end

    it "redirects to the topic the user was invited to after activating account" do
      TopicInvite.create!(invite: invite, topic: topic)

      invite_form.open(invite.invite_key)

      invite_form.fill_username("john")
      invite_form.fill_password("supersecurepassword")

      expect(invite_form).to have_valid_fields

      invite_form.click_create_account
      expect(invite_form).to have_successful_message

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to contain_exactly(invite.email)
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]

      browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      activate_account.click_activate_account

      expect(browser_page).to PlaywrightMatchers.have_url("/t/#{topic.slug}/#{topic.id}")
    end

    it "redirects to a new-topic after signin and keeps the query" do
      category = Fabricate(:category)
      SiteSetting.create_topic_allowed_groups = "0"

      browser_page
        .goto("/new-topic?category_id=#{category.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      signup_page
        .open
        .fill_email("johndoe@awesomeemail.com")
        .fill_username("john11122")
        .fill_password("supersecurepassword")

      expect(signup_page).to have_valid_fields

      signup_page.click_create_account

      expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")

      mail = ActionMailer::Base.deliveries.first
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]

      browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

      activate_account.click_activate_account

      expect(browser_page).to PlaywrightMatchers.have_url("/c/#{category.id}")
      expect(composer).to be_opened
    end

    it "cannot signup with a common password" do
      signup_page.open.fill_email(invite.email).fill_username("john").fill_password("0123456789")
      expect(signup_page).to have_valid_fields

      signup_page.click_create_account
      expect(signup_page).to have_displayed_content(
        I18n.t("activerecord.errors.models.user_password.attributes.password.common"),
      )
    end

    context "with invite code" do
      before { SiteSetting.invite_code = "cupcake" }

      it "can signup with valid code" do
        signup_page
          .open
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_code("cupcake")
        expect(signup_page).to have_valid_fields

        signup_page.click_create_account
        expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")
      end

      it "cannot signup with invalid code" do
        signup_page
          .open
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_code("pudding")
        expect(signup_page).to have_valid_fields

        signup_page.click_create_account
        expect(signup_page).to have_displayed_content(I18n.t("login.wrong_invite_code"))
        expect(
          signup_page.locator(".account-created").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
      end
    end

    context "when there are required user fields" do
      before do
        Fabricate(
          :user_field,
          name: "Occupation",
          requirement: "on_signup",
          description: "What you do for work",
        )
      end

      it "can signup when filling the custom field" do
        signup_page
          .open
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_custom_field("Occupation", "Jedi")
        expect(signup_page).to have_valid_fields

        signup_page.click_create_account
        expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")
      end

      it "cannot signup without filling the custom field" do
        signup_page
          .open
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")

        expect(signup_page).to have_displayed_content("What you do for work")

        signup_page.click_create_account
        expect(signup_page).to have_displayed_content(
          I18n.t("js.user_fields.required", name: "Occupation"),
        )
        expect(
          signup_page.locator(".account-created").filter(visible: true),
        ).to PlaywrightMatchers.have_count(0)
        expect(
          signup_page.locator(".tip.bad").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(
          [browser_text_pattern("Please enter a value for \"Occupation\"")],
          useInnerText: true,
        )
      end
    end

    context "when user requires approval" do
      before do
        SiteSetting.must_approve_users = true
        SiteSetting.auto_approve_email_domains = "awesomeemail.com"
      end

      it "can signup but cannot login until approval" do
        signup_page
          .open
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")
        expect(signup_page).to have_valid_fields
        signup_page.click_create_account

        wait_for(timeout: 5) { User.find_by(username: "john") != nil }
        expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")

        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        login_page.open
        login_page.fill_username("john")
        login_page.fill_password("supersecurepassword")
        login_page.click_login
        expect(login_page).to have_displayed_content(I18n.t("login.not_approved"))

        user = User.find_by(username: "john")
        user.update!(approved: true)
        EmailToken.confirm(Fabricate(:email_token, user: user).token)

        login_page.click_login

        expect(browser_page).to PlaywrightMatchers.have_url("/")
        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end

      it "can login directly when using an auto approved email" do
        signup_page
          .open
          .fill_email("johndoe@awesomeemail.com")
          .fill_username("john")
          .fill_password("supersecurepassword")

        expect(signup_page).to have_valid_fields

        signup_page.click_create_account

        expect(browser_page).to PlaywrightMatchers.have_url("/u/account-created")

        user = User.find_by(username: "john")
        EmailToken.confirm(Fabricate(:email_token, user:).token)
        browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        login_page.open.fill_username("john").fill_password("supersecurepassword").click_login

        expect(browser_page).to PlaywrightMatchers.have_url("/")
        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end

    context "when site has subfolder install" do
      before { set_subfolder "/discuss" }

      it "can signup and activate account" do
        browser_page.goto("/discuss/signup").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        signup_page
          .fill_email(invite.email)
          .fill_username("john")
          .fill_password("supersecurepassword")
        expect(signup_page).to have_valid_fields

        signup_page.click_create_account
        expect(browser_page).to PlaywrightMatchers.have_url("/discuss/u/account-created")

        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to contain_exactly(invite.email)
        activation_link = mail.body.to_s[%r{\S+/u/activate-account/\S+}]

        browser_page.goto(activation_link).tap { SystemBrowserBootstrap.wait_for(browser_page) }

        activate_account.click_activate_account
        activate_account.click_continue

        expect(browser_page).to PlaywrightMatchers.have_url("/discuss/")
        expect(
          browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
      end
    end
  end

  context "when the email domain is blocked" do
    before do
      SiteSetting.hide_email_address_taken = false
      SiteSetting.blocked_email_domains = "example.com"
    end

    it "cannot signup" do
      signup_page
        .open
        .fill_email("blocked@example.com")
        .fill_username("john")
        .fill_password("supersecurepassword")
      expect(signup_page).to have_valid_username
      expect(signup_page).to have_valid_password
      expect(signup_page).to have_displayed_content(I18n.t("user.email.not_allowed"))
    end
  end

  context "when site is invite only" do
    before { SiteSetting.invite_only = true }

    it "cannot open the signup page" do
      signup_page.open
      expect(signup_page).to be_closed
      expect(
        browser_root.locator(".sign-up-button").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)

      login_page.open_from_header
      expect(
        login_page.locator("#new-account-link").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end

    it "can signup with invite link" do
      invite = Fabricate(:invite)
      browser_page
        .goto("/invites/#{invite.invite_key}?t=#{invite.email_token}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      browser_root
        .locator("#new-account-password")
        .filter(visible: true)
        .fill("supersecurepassword")
      browser_root.locator("#new-account-username").filter(visible: true).fill("johndoe")
      expect(
        browser_root
          .locator(".username-input")
          .filter(visible: true)
          .locator("#username-validation.good")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root
          .locator(".create-account__password-tip-validation")
          .filter(visible: true)
          .locator("#password-validation.good")
          .filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      browser_root.locator(".invitation-cta__accept").filter(visible: true).click

      expect(browser_page).to PlaywrightMatchers.have_url("/")
      expect(
        browser_root.locator(".header-dropdown-toggle.current-user").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
    end
  end

  it "correctly loads the invites page" do
    inviter = Fabricate(:user)
    invite = Fabricate(:invite, invited_by: inviter)
    Fabricate(:user_field, name: "test", show_on_signup: false)

    browser_page
      .goto("/invites/#{invite.invite_key}?t=#{invite.email_token}")
      .tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".invited-by .user-info[data-username='#{inviter.username}']").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".user-field-test").filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)
    browser_root.locator(".invitation-cta__sign-in").filter(visible: true).click
    expect(
      browser_root.locator("#login-form").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    browser_page.go_back.tap { SystemBrowserBootstrap.wait_for(browser_page) }
    expect(
      browser_root.locator(".invited-by .user-info[data-username='#{inviter.username}']").filter(
        visible: true,
      ),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  describe "full name field" do
    context "when full_name_requirement is optional_at_signup" do
      before { SiteSetting.full_name_requirement = "optional_at_signup" }

      context "when login_required is true" do
        before { SiteSetting.login_required = true }

        it "displays the name field" do
          signup_page.open
          expect(signup_page).to have_name_input
        end
      end

      context "when enable_names is false" do
        before { SiteSetting.enable_names = false }

        it "hides the name field" do
          signup_page.open
          expect(signup_page).to have_name_input
        end
      end
    end

    context "when full_name_requirement is hidden_at_signup" do
      before { SiteSetting.full_name_requirement = "hidden_at_signup" }

      it "hides the name field" do
        signup_page.open
        expect(signup_page).to have_no_name_input
      end
    end

    context "when full_name_requirement is required_at_signup" do
      before { SiteSetting.full_name_requirement = "required_at_signup" }

      it "displays the name field" do
        signup_page.open
        expect(signup_page).to have_name_input
      end

      context "when enable_names is false" do
        before { SiteSetting.enable_names = false }

        it "hides the name field" do
          signup_page.open
          expect(signup_page).to have_name_input
        end
      end
    end
  end

  describe "user custom fields" do
    it "shows tips if required but not selected" do
      user_field_text = Fabricate(:user_field)
      user_field_dropdown = Fabricate(:user_field_dropdown)

      signup_page.open
      browser_root.locator(".signup-page-cta__signup").filter(visible: true).click

      expect(signup_page).to have_displayed_content(
        I18n.t("js.user_fields.required", name: user_field_text.name),
      )
      expect(signup_page).to have_displayed_content(
        I18n.t("js.user_fields.required_select", name: user_field_dropdown.name),
      )
    end

    it "does not show fields that are configured hidden on signup" do
      Fabricate(:user_field, name: "test", show_on_signup: false)

      signup_page.open

      expect(
        signup_page.locator(".user-field-test").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
    end
  end
end

describe "Signup" do
  context "when desktop" do
    include_examples "signup scenarios"
  end

  context "when mobile", mobile: true do
    include_examples "signup scenarios"
  end
end
