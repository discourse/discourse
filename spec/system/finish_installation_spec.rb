# frozen_string_literal: true

RSpec.describe "Finish Installation", type: :system do
  let(:finish_installation_page) { PageObjects::Pages::FinishInstallation.new }

  context "when has_login_hint is false" do
    before { SiteSetting.has_login_hint = false }

    it "denies access" do
      finish_installation_page.visit_index
      expect(finish_installation_page).to have_access_denied
    end
  end

  context "when has_login_hint is true" do
    before do
      SiteSetting.has_login_hint = true
      GlobalSetting.stubs(:developer_emails).returns("admin@example.com,other@example.com")
    end

    it "shows validation error when username is blank" do
      finish_installation_page.visit_register.fill_password("supersecurepassword").submit
      expect(finish_installation_page).to have_username_error
    end

    it "shows validation error when password is blank" do
      finish_installation_page.visit_register.fill_username("newadmin").submit
      expect(finish_installation_page).to have_password_error
    end

    it "shows validation error when password is too short" do
      finish_installation_page
        .visit_register
        .fill_username("newadmin")
        .fill_password("short")
        .submit
      expect(finish_installation_page).to have_password_error("too short")
    end

    it "registers admin and redirects to confirm email page" do
      finish_installation_page
        .visit_register
        .select_email("admin@example.com")
        .fill_username("newadmin")
        .fill_password("supersecurepassword")
        .submit

      expect(finish_installation_page).to be_redirected_to_confirm_email
      expect(User.find_by(username: "newadmin")).to have_attributes(
        email: "admin@example.com",
        trust_level: 1,
      )
    end

    it "handles multiple developer emails" do
      finish_installation_page
        .visit_register
        .select_email("other@example.com")
        .fill_username("otheradmin")
        .fill_password("supersecurepassword")
        .submit

      expect(finish_installation_page).to be_redirected_to_confirm_email
      expect(User.find_by(username: "otheradmin")).to be_present
    end

    it "resends activation email when user already exists" do
      Fabricate(:user, email: "admin@example.com")

      expect {
        finish_installation_page
          .visit_register
          .select_email("admin@example.com")
          .fill_username("differentuser")
          .fill_password("supersecurepassword")
          .submit
      }.to change { Jobs::CriticalUserEmail.jobs.size }.by(1)

      expect(finish_installation_page).to be_redirected_to_confirm_email
    end

    it "does not send email when user is already active and confirmed" do
      user = Fabricate(:user, email: "admin@example.com", active: true)
      user.activate

      expect {
        finish_installation_page
          .visit_register
          .select_email("admin@example.com")
          .fill_username("differentuser")
          .fill_password("supersecurepassword")
          .submit
      }.not_to change { Jobs::CriticalUserEmail.jobs.size }

      expect(finish_installation_page).to be_redirected_to_confirm_email
    end
  end
end
