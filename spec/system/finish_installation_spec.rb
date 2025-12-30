# frozen_string_literal: true

RSpec.describe "Finish Installation", type: :system do
  let(:finish_installation_page) { PageObjects::Pages::FinishInstallation.new }

  context "when has_login_hint is false" do
    before { SiteSetting.has_login_hint = false }

    it "denies access" do
      finish_installation_page.visit_page
      expect(finish_installation_page).to have_access_denied
    end
  end

  context "when has_login_hint is true" do
    before { SiteSetting.has_login_hint = true }

    context "when DISCOURSE_SKIP_EMAIL_SETUP=1" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DISCOURSE_SKIP_EMAIL_SETUP").and_return("1")
      end

      context "when ID registration is successful" do
        before do
          GlobalSetting.stubs(:developer_emails).returns("dev1@example.com,dev2@example.com")

          stub_request(:post, "https://id.discourse.com/challenge").to_return(
            status: 200,
            body: { domain: Discourse.current_hostname, token: "test_token" }.to_json,
          )
          stub_request(:post, "https://id.discourse.com/register").to_return(
            status: 200,
            body: { client_id: "test_client_id", client_secret: "test_client_secret" }.to_json,
          )
        end

        it "enables Discourse ID and shows login button" do
          finish_installation_page.visit_page

          expect(finish_installation_page).to have_discourse_id_button
          expect(finish_installation_page).to have_no_register_button
          expect(finish_installation_page).to have_no_error_message
        end

        it "creates multiple admin users when multiple emails are configured" do
          finish_installation_page.visit_page
          finish_installation_page.click_login_with_discourse_id

          user1 = User.find_by_email("dev1@example.com")
          user2 = User.find_by_email("dev2@example.com")

          expect(user1).to be_present
          expect(user1.admin).to eq(true)
          expect(user2).to be_present
          expect(user2.admin).to eq(true)

          expect(page.current_url).to include("id.discourse.com")
        end

        it "skips creating users that already exist" do
          Fabricate(:user, email: "dev1@example.com", admin: false)
          Fabricate(:user, email: "dev2@example.com", admin: false)
          initial_user_count = User.count

          finish_installation_page.visit_page
          finish_installation_page.click_login_with_discourse_id

          expect(User.count).to eq(initial_user_count)
        end
      end

      context "when developer_emails is empty" do
        before { GlobalSetting.stubs(:developer_emails).returns("") }

        it "shows error message about missing allowed emails" do
          finish_installation_page.visit_page

          expect(finish_installation_page).to have_no_discourse_id_button
          expect(finish_installation_page).to have_no_register_button
          expect(finish_installation_page).to have_error_message
          expect(finish_installation_page.error_message_text).to include(
            I18n.t("finish_installation.discourse_id.no_allowed_emails"),
          )
        end
      end

      context "when ID registration fails with an error" do
        before do
          GlobalSetting.stubs(:developer_emails).returns("dev1@example.com,dev2@example.com")

          failed_context = Service::Base::Context.new
          failed_context.fail(error: "Failed to connect to Discourse ID")
          allow(DiscourseId::Register).to receive(:call).and_return(failed_context)
        end

        it "shows error message and no login button" do
          finish_installation_page.visit_page

          expect(finish_installation_page).to have_no_discourse_id_button
          expect(finish_installation_page).to have_no_register_button
          expect(finish_installation_page).to have_error_message
        end
      end
    end

    context "when using local registration" do
      before do
        GlobalSetting.stubs(:developer_emails).returns("admin@example.com,other@example.com")
      end

      it "shows local register form button" do
        finish_installation_page.visit_page

        expect(finish_installation_page).to have_register_button
        expect(finish_installation_page).to have_no_discourse_id_button
        expect(finish_installation_page).to have_no_error_message
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
      end
    end
  end
end
