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
end
