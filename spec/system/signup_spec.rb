# frozen_string_literal: true

describe "Signup", type: :system do
  let(:login_modal) { PageObjects::Modals::Login.new }
  let(:signup_modal) { PageObjects::Modals::Signup.new }

  context "when anyone can create an account" do
    it "can signup and activate account" do
      Jobs.run_immediately!

      signup_modal.open
      signup_modal.fill_email("johndoe@example.com")
      signup_modal.fill_username("john")
      signup_modal.fill_password("supersecurepassword")
      expect(signup_modal).to have_valid_email
      expect(signup_modal).to have_valid_username
      expect(signup_modal).to have_valid_password

      signup_modal.confirm_signup

      wait_for(timeout: 5) { ActionMailer::Base.deliveries.count != 0 }

      mail = ActionMailer::Base.deliveries.last
      expect(mail.to).to contain_exactly("johndoe@example.com")
      activation_link = mail.body.to_s[%r{/u/activate-account/\S+}, 0]

      visit "/"
      visit activation_link
      find("#activate-account-button").click

      visit "/"
      expect(page).to have_css(".header-dropdown-toggle.current-user")
    end

    context "with invite code" do
      before { SiteSetting.invite_code = "cupcake" }

      it "can signup with valid code" do
        signup_modal.open
        signup_modal.fill_email("johndoe@example.com")
        signup_modal.fill_username("john")
        signup_modal.fill_password("supersecurepassword")
        signup_modal.fill_code("cupcake")
        expect(signup_modal).to have_valid_email
        expect(signup_modal).to have_valid_username
        expect(signup_modal).to have_valid_password

        signup_modal.confirm_signup
        expect(page).to have_css(".account-created")
      end

      it "can not signup with invalid code" do
        signup_modal.open
        signup_modal.fill_email("johndoe@example.com")
        signup_modal.fill_username("john")
        signup_modal.fill_password("supersecurepassword")
        signup_modal.fill_code("pudding")
        expect(signup_modal).to have_valid_email
        expect(signup_modal).to have_valid_username
        expect(signup_modal).to have_valid_password

        signup_modal.confirm_signup
        expect(signup_modal).to have_content(I18n.t("login.wrong_invite_code"))
        expect(signup_modal).to have_no_css(".account-created")
      end
    end

    context "when user requires aproval" do
      it "can signup" do
        # TODO: add test
      end
    end
  end

  context "when site is invite only" do
    before { SiteSetting.invite_only = true }

    it "cannot open signup modal" do
      signup_modal.open
      expect(signup_modal).to be_closed
      expect(page).to have_no_css(".sign-up-button")
      login_modal.open_from_header
      expect(login_modal).to have_no_css("#new-account-link")
    end

    it "can signup with invite link" do
      # TODO: add test
    end
  end
end

# auto approve email domains
# allowed email domains
# blocked email domains
