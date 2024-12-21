#frozen_string_literal: true

describe "Admin API Keys Page", type: :system do
  fab!(:current_user) { Fabricate(:admin) }

  let(:api_keys_page) { PageObjects::Pages::AdminApiKeys.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    Fabricate(:api_key, description: "Integration")

    sign_in(current_user)
  end

  it "shows a list of API keys" do
    api_keys_page.visit_page

    expect(api_keys_page).to have_api_key_listed("Integration")
  end

  it "can add a new API key" do
    api_keys_page.visit_page
    api_keys_page.add_api_key(description: "Second Integration")

    expect(api_keys_page).to have_api_key_listed("Second Integration")
  end
end
