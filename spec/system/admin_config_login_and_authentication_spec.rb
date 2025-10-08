# frozen_string_literal: true

describe "Admin Config Login and Authentication", type: :system do
  fab!(:current_user, :admin)

  let(:admin_login_page) { PageObjects::Pages::AdminLoginAndAuthentication.new }

  before { sign_in(current_user) }

  it "shows the login and authentication tabs and allows navigation between them" do
    admin_login_page.visit

    admin_login_page.click_tab("authenticators")
    expect(admin_login_page).to have_setting("enable_google_oauth2_logins")

    admin_login_page.click_tab("discourseconnect")
    expect(admin_login_page).to have_setting("enable_discourse_connect")
  end
end
