# frozen_string_literal: true

shared_examples "signup scenarios" do |signup_page_object, login_page_object|
  let(:login_form) { login_page_object }
  let(:signup_form) { signup_page_object }
  let(:invite_form) { PageObjects::Pages::InviteForm.new }
  let(:activate_account) { PageObjects::Pages::ActivateAccount.new }
  let(:invite) { Fabricate(:invite, email: "johndoe@example.com") }
  let(:topic) { Fabricate(:topic, title: "Super cool topic") }

  context "when anyone can create an account" do
    before { Jobs.run_immediately! }

    it "can signup" do
      signup_form
        .open
        .fill_email("johndoe@example.com")
        .fill_username("john")
        .fill_password("supersecurepassword")
      expect(signup_form).to have_valid_fields

      signup_form.click_create_account
      expect(page).to have_css(".account-created")
    end

    it "can signup and activate account" do
      signup_form
        .open
        .fill_email("johndoe@example.com")
        .fill_username("john")
        .fill_password("supersecurepassword")
      expect(signup_form).to have_valid_fields

      signup_form.click_create_account
      expect(page).to have_css(".account-created")

      mail = ActionMailer::Base.deliveries.first
      expect(mail.to).to contain_exactly("johndoe@example.com")
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]

      visit activation_link

      activate_account.click_activate_account
      activate_account.click_continue

      expect(page).to have_current_path("/")
      expect(page).to have_css(".header-dropdown-toggle.current-user")
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
      expect(mail.to).to contain_exactly("johndoe@example.com")
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}]

      visit activation_link

      activate_account.click_activate_account

      expect(page).to have_current_path("/t/#{topic.slug}/#{topic.id}")
    end

    context "with invite code" do
      before { SiteSetting.invite_code = "cupcake" }

      it "can signup with valid code" do
        signup_form
          .open
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_code("cupcake")
        expect(signup_form).to have_valid_fields

        signup_form.click_create_account
        expect(page).to have_css(".account-created")
      end

      it "cannot signup with invalid code" do
        signup_form
          .open
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_code("pudding")
        expect(signup_form).to have_valid_fields

        signup_form.click_create_account
        expect(signup_form).to have_content(I18n.t("login.wrong_invite_code"))
        expect(signup_form).to have_no_css(".account-created")
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
        signup_form
          .open
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
          .fill_custom_field("Occupation", "Jedi")
        expect(signup_form).to have_valid_fields

        signup_form.click_create_account
        expect(page).to have_css(".account-created")
      end

      it "cannot signup without filling the custom field" do
        signup_form
          .open
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
          .click_create_account
        expect(signup_form).to have_content(I18n.t("js.user_fields.required", name: "Occupation"))
        expect(signup_form).to have_no_css(".account-created")
      end
    end

    context "when user requires approval" do
      before do
        SiteSetting.must_approve_users = true
        SiteSetting.auto_approve_email_domains = "awesomeemail.com"
      end

      it "can signup but cannot login until approval" do
        signup_form
          .open
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
        expect(signup_form).to have_valid_fields
        signup_form.click_create_account

        wait_for(timeout: 5) { User.find_by(username: "john") != nil }

        visit "/"
        login_form.open
        login_form.fill_username("john")
        login_form.fill_password("supersecurepassword")
        login_form.click_login
        expect(login_form).to have_content(I18n.t("login.not_approved"))

        user = User.find_by(username: "john")
        user.update!(approved: true)
        EmailToken.confirm(Fabricate(:email_token, user: user).token)

        login_form.click_login
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end

      it "can login directly when using an auto approved email" do
        signup_form
          .open
          .fill_email("johndoe@awesomeemail.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
        expect(signup_form).to have_valid_fields
        signup_form.click_create_account

        wait_for(timeout: 5) { User.find_by(username: "john") != nil }
        user = User.find_by(username: "john")
        EmailToken.confirm(Fabricate(:email_token, user: user).token)

        visit "/"
        login_form.open
        login_form.fill_username("john")
        login_form.fill_password("supersecurepassword")
        login_form.click_login
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end

    context "when site has subfolder install" do
      before { set_subfolder "/discuss" }

      it "can signup and activate account" do
        visit("/discuss/signup")
        signup_form
          .fill_email("johndoe@example.com")
          .fill_username("john")
          .fill_password("supersecurepassword")
        expect(signup_form).to have_valid_fields

        signup_form.click_create_account
        expect(page).to have_css(".account-created")

        mail = ActionMailer::Base.deliveries.first
        expect(mail.to).to contain_exactly("johndoe@example.com")
        activation_link = mail.body.to_s[%r{\S+/u/activate-account/\S+}]

        visit activation_link

        activate_account.click_activate_account
        activate_account.click_continue

        expect(page).to have_current_path("/discuss/")
        expect(page).to have_css(".header-dropdown-toggle.current-user")
      end
    end
  end

  context "when the email domain is blocked" do
    before do
      SiteSetting.hide_email_address_taken = false
      SiteSetting.blocked_email_domains = "example.com"
    end

    it "cannot signup" do
      signup_form
        .open
        .fill_email("johndoe@example.com")
        .fill_username("john")
        .fill_password("supersecurepassword")
      expect(signup_form).to have_valid_username
      expect(signup_form).to have_valid_password
      expect(signup_form).to have_content(I18n.t("user.email.not_allowed"))
    end
  end

  context "when site is invite only" do
    before { SiteSetting.invite_only = true }

    it "cannot open the signup modal" do
      signup_form.open
      expect(signup_form).to be_closed
      expect(page).to have_no_css(".sign-up-button")

      login_form.open_from_header
      expect(login_form).to have_no_css("#new-account-link")
    end

    it "can signup with invite link" do
      invite = Fabricate(:invite, email: "johndoe@example.com")
      visit "/invites/#{invite.invite_key}?t=#{invite.email_token}"

      find("#new-account-password").fill_in(with: "supersecurepassword")
      find(".username-input").has_css?("#username-validation.good")
      find(".create-account__password-tip-validation").has_css?("#password-validation.good")
      find(".invitation-cta__accept").click

      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end
  end

  it "correctly loads the invites page" do
    inviter = Fabricate(:user)
    invite = Fabricate(:invite, email: "johndoe@example.com", invited_by: inviter)
    visit "/invites/#{invite.invite_key}?t=#{invite.email_token}"

    expect(page).to have_css(".invited-by .user-info[data-username='#{inviter.username}']")
    find(".invitation-cta__sign-in").click

    if page.has_css?(".d-modal.login-modal", wait: 0)
      if page.has_css?("html.mobile-view", wait: 0)
        expect(page).to have_css(".d-modal.is-animating")
        expect(page).to have_css(".d-modal:not(.is-animating)")
      end
      find(".d-modal .modal-close").click
    else
      page.go_back
    end

    expect(page).to have_css(".invited-by .user-info[data-username='#{inviter.username}']")
  end
end

describe "Signup", type: :system do
  context "when desktop" do
    include_examples "signup scenarios",
                     PageObjects::Modals::Signup.new,
                     PageObjects::Modals::Login.new
  end

  context "when mobile", mobile: true do
    include_examples "signup scenarios",
                     PageObjects::Modals::Signup.new,
                     PageObjects::Modals::Login.new
  end

  context "when fullpage desktop" do
    before { SiteSetting.full_page_login = true }
    include_examples "signup scenarios",
                     PageObjects::Pages::Signup.new,
                     PageObjects::Pages::Login.new
  end

  context "when fullpage mobile", mobile: true do
    before { SiteSetting.full_page_login = true }
    include_examples "signup scenarios",
                     PageObjects::Pages::Signup.new,
                     PageObjects::Pages::Login.new
  end
end
