#frozen_string_literal: true

describe "Admin API Keys Page" do
  fab!(:current_user, :admin)

  let(:api_keys_page) { PageObjects::Pages::AdminApiKeys.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before do
    Fabricate(:api_key, description: "Integration")

    sign_in(current_user)
  end

  it "lets the admin inspect, create and rename API keys" do
    api_keys_page.visit_page

    aggregate_failures "existing key" do
      expect(api_keys_page).to have_api_key_listed("Integration")
    end

    api_keys_page.add_api_key(description: "Second Integration")

    aggregate_failures "generated key" do
      expect(api_keys_page).to have_generated_api_key
      expect(api_keys_page).to have_copy_button
      expect(api_keys_page).to have_warning_banner
    end

    api_keys_page.click_continue

    aggregate_failures "saved key" do
      expect(api_keys_page).to have_api_key_listed("Second Integration")
    end

    api_keys_page.click_edit("Integration")
    api_keys_page.edit_description("Old Integration")
    api_keys_page.click_back

    aggregate_failures "renamed key" do
      expect(api_keys_page).to have_api_key_listed("Old Integration")
    end
  end

  it "lets the admin revoke, restore and permanently delete an API key" do
    api_keys_page.visit_page
    api_keys_page.click_edit("Integration")
    api_keys_page.click_revoke
    api_keys_page.click_back

    aggregate_failures "revoked key" do
      expect(api_keys_page).to have_revoked_api_key_listed("Integration")
    end

    api_keys_page.click_edit("Integration")
    api_keys_page.click_unrevoke
    api_keys_page.click_revoke
    api_keys_page.click_unrevoke
    api_keys_page.click_back

    aggregate_failures "restored key" do
      expect(api_keys_page).to have_unrevoked_api_key_listed("Integration")
    end

    api_keys_page.click_edit("Integration")
    api_keys_page.click_revoke
    api_keys_page.click_delete

    aggregate_failures "deleted key" do
      expect(api_keys_page).to have_current_path("/admin/api/keys")
      expect(api_keys_page).to have_no_api_key_listed("Integration")
    end
  end

  it "displays scopes when viewing a granular API key from the list" do
    Fabricate(
      :api_key,
      description: "Granular Key",
      api_key_scopes: [Fabricate.build(:api_key_scope, resource: "topics", action: "read")],
    )

    api_keys_page.visit_page
    api_keys_page.click_edit("Granular Key")

    expect(api_keys_page).to have_scopes_displayed
    expect(api_keys_page).to have_scope(resource: "topics", action: "read")
  end
end
