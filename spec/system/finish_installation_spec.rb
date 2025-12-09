# frozen_string_literal: true

RSpec.describe "Finish Installation", type: :system do
  let(:finish_installation_page) { PageObjects::Pages::FinishInstallation.new }

  before do
    SiteSetting.has_login_hint = true
    GlobalSetting.stubs(:developer_emails).returns("dev@example.com")
  end

  describe "Discourse ID setup scenarios" do
    context "when DISCOURSE_SKIP_EMAIL_SETUP is set and ID registration is successful" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DISCOURSE_SKIP_EMAIL_SETUP").and_return("1")

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

      it "creates admin users from developer_emails" do
        finish_installation_page.visit_page

        user = User.find_by_email("dev@example.com")
        expect(user).to be_present
        expect(user.admin).to eq(true)
        expect(user.trust_level).to eq(TrustLevel[4])
        expect(user.active).to eq(true)
      end

      it "creates multiple admin users when multiple emails are configured" do
        GlobalSetting.stubs(:developer_emails).returns("dev1@example.com,dev2@example.com")

        finish_installation_page.visit_page

        user1 = User.find_by_email("dev1@example.com")
        user2 = User.find_by_email("dev2@example.com")

        expect(user1).to be_present
        expect(user1.admin).to eq(true)
        expect(user2).to be_present
        expect(user2.admin).to eq(true)
      end

      it "skips creating users that already exist" do
        existing_user = Fabricate(:user, email: "dev@example.com", admin: false)
        initial_user_count = User.count

        finish_installation_page.visit_page

        expect(User.count).to eq(initial_user_count)
        existing_user.reload
        expect(existing_user.admin).to eq(false)
      end
    end

    context "when DISCOURSE_SKIP_EMAIL_SETUP=1 and developer_emails is empty" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DISCOURSE_SKIP_EMAIL_SETUP").and_return("1")
        GlobalSetting.stubs(:developer_emails).returns("")

        stub_request(:post, "https://id.discourse.com/challenge").to_return(
          status: 200,
          body: { domain: Discourse.current_hostname, token: "test_token" }.to_json,
        )
        stub_request(:post, "https://id.discourse.com/register").to_return(
          status: 200,
          body: { client_id: "test_client_id", client_secret: "test_client_secret" }.to_json,
        )
      end

      it "shows error message about missing allowed emails" do
        finish_installation_page.visit_page

        expect(finish_installation_page).to have_no_discourse_id_button
        expect(finish_installation_page).to have_no_register_button
        expect(finish_installation_page).to have_error_message
        expect(finish_installation_page.error_message_text).to include(
          "No allowed emails configured",
        )
      end
    end

    context "when DISCOURSE_SKIP_EMAIL_SETUP=1 and ID registration fails with an error" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("DISCOURSE_SKIP_EMAIL_SETUP").and_return("1")

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

    context "when DISCOURSE_SKIP_EMAIL_SETUP is not provided" do
      it "shows local register form button" do
        finish_installation_page.visit_page

        expect(finish_installation_page).to have_register_button
        expect(finish_installation_page).to have_no_discourse_id_button
        expect(finish_installation_page).to have_no_error_message
      end
    end
  end

  it "renders first screen" do
    visit "/finish-installation"

    find(".finish-installation__register").click

    expect(page).to have_css(".wizard-container__combobox")
    expect(page).to have_css(".input-area")
    expect(page).to have_css(".wizard-container__button")

    # TODO: we could add more steps here to ensure full flow works
  end
end
