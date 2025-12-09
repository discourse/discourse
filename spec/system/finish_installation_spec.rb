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

        success_context = Service::Base::Context.new
        success_context[:client_id] = "test_client_id"
        success_context[:client_secret] = "test_client_secret"
        allow(DiscourseId::Register).to receive(:call).and_return(success_context)
      end

      it "enables Discourse ID and shows login button" do
        finish_installation_page.visit_page

        expect(finish_installation_page).to have_discourse_id_button
        expect(finish_installation_page).to have_no_register_button
        expect(finish_installation_page).to have_no_error_message
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
