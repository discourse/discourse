# frozen_string_literal: true

RSpec.describe "Discourse Workflows - Credentials" do
  fab!(:admin)

  let(:credentials_page) { PageObjects::Pages::DiscourseWorkflows::Credentials.new }

  before { sign_in(admin) }

  it "creates a new credential" do
    credentials_page.visit_index
    credentials_page.click_add_credential
    credentials_page.fill_credential_name("production_auth")
    credentials_page.select_credential_type("Basic Auth")
    credentials_page.fill_credential_field("user", "alice")
    credentials_page.fill_credential_field("password", "secret123")
    credentials_page.submit_credential_modal

    expect(credentials_page).to have_credential("production_auth")
  end

  it "saves OAuth2 app details, offers Test connection, and keeps the saved secret masked" do
    credentials_page.visit_index
    credentials_page.click_add_credential
    credentials_page.fill_credential_name("Contacts API")
    credentials_page.select_credential_type(I18n.t("discourse_workflows.oauth2.display_name"))
    credentials_page.fill_credential_field("client_id", "client-id")
    credentials_page.fill_credential_field("client_secret", "client-secret")
    credentials_page.fill_credential_field("token_url", "https://auth.example.com/token")
    credentials_page.fill_credential_field("api_origin", "https://api.example.com")

    credentials_page.submit_credential_modal

    expect(credentials_page).to have_credential("Contacts API")
    expect(credentials_page).to have_connection_status("Not tested")
    expect(credentials_page).to have_connection_action("Test connection")

    page.refresh
    credentials_page.edit_credential("Contacts API")
    expect(credentials_page).to have_masked_client_secret
    credentials_page.submit_credential_modal
    expect(credentials_page).to have_connection_action("Test connection")
  end
end
