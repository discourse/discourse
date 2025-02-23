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

    expect(api_keys_page).to have_generated_api_key

    api_keys_page.click_continue

    expect(api_keys_page).to have_api_key_listed("Second Integration")
  end

  it "can edit existing API keys" do
    api_keys_page.visit_page
    api_keys_page.click_edit("Integration")
    api_keys_page.edit_description("Old Integration")
    api_keys_page.click_back

    expect(api_keys_page).to have_api_key_listed("Old Integration")
  end

  it "can revoke API keys" do
    api_keys_page.visit_page
    api_keys_page.click_edit("Integration")
    api_keys_page.click_revoke
    api_keys_page.click_back

    expect(api_keys_page).to have_revoked_api_key_listed("Integration")
  end

  it "can undo revokation of API keys" do
    api_keys_page.visit_page
    api_keys_page.click_edit("Integration")
    api_keys_page.click_revoke
    api_keys_page.click_unrevoke
    api_keys_page.click_back

    expect(api_keys_page).to have_unrevoked_api_key_listed("Integration")
  end

  it "can permanently delete revoked API keys" do
    api_keys_page.visit_page
    api_keys_page.click_edit("Integration")
    api_keys_page.click_revoke
    api_keys_page.click_delete

    expect(api_keys_page).to have_current_path("/admin/api/keys")
    expect(api_keys_page).to have_no_api_key_listed("Integration")
  end
end
