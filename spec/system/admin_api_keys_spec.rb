#frozen_string_literal: true

describe "Admin API Keys Page" do
  fab!(:current_user, :admin)

  let(:api_keys_page) { PageObjects::Pages::AdminApiKeys.new }

  before do
    Fabricate(:api_key, description: "Integration")

    sign_in(current_user)
  end

  it "lets an admin list, create, edit, revoke, restore and delete API keys" do
    api_keys_page.visit_page

    expect(api_keys_page).to have_api_key_listed("Integration")

    api_keys_page.add_api_key(description: "New service")

    expect(api_keys_page).to have_generated_api_key
    expect(api_keys_page).to have_copy_button
    expect(api_keys_page).to have_warning_banner

    api_keys_page.click_continue

    expect(api_keys_page).to have_api_key_listed("New service")
    expect(api_keys_page).to have_api_key_listed("Integration")

    api_keys_page.click_edit("New service")
    api_keys_page.click_revoke
    api_keys_page.click_delete
    expect(api_keys_page).to have_no_api_key_listed("New service")

    api_keys_page.click_edit("Integration")
    api_keys_page.edit_description("Old Integration")
    api_keys_page.click_back

    expect(api_keys_page).to have_api_key_listed("Old Integration")

    api_keys_page.click_edit("Old Integration")
    api_keys_page.click_revoke
    api_keys_page.click_back

    expect(api_keys_page).to have_revoked_api_key_listed("Old Integration")

    api_keys_page.click_edit("Old Integration")
    api_keys_page.click_unrevoke
    api_keys_page.click_back

    expect(api_keys_page).to have_unrevoked_api_key_listed("Old Integration")

    api_keys_page.click_edit("Old Integration")
    api_keys_page.click_revoke
    api_keys_page.click_delete

    expect(api_keys_page).to have_current_path("/admin/api/keys")
    expect(api_keys_page).to have_no_api_key_listed("Old Integration")
    expect(page).to have_css(
      ".admin-api_keys .admin-config-area-empty-list",
      text: I18n.t("admin_js.admin.api_keys.no_api_keys"),
    )
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
