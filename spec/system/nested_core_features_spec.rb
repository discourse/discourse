# frozen_string_literal: true

# Parts of the core features examples can be skipped like so:
#   it_behaves_like "having working core features", skip_examples: %i[login likes]
#
# List of keywords for skipping examples:
# login, likes, profile, topics, topics:read, topics:reply, topics:create,
# search, search:quick_search, search:full_page
#
# For more details, see https://meta.discourse.org/t/-/361381
RSpec.describe "Core features" do
  before { SiteSetting.nested_replies_enabled = true }

  # Because of how routes are defined it _can_ interfere with how scope mappings work,
  # this test checks if we can create an API key, before rendering, this route checks for all scope mappings
  it "allows creating API keys" do
    admin = Fabricate(:admin)
    sign_in(admin)

    browser_page.goto("/admin/api/keys/new").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    dialog = PageObjects::Components::Dialog.new

    expect(dialog).to be_closed # if it failed to load the page, the dialog will be open with an error message

    expect(
      browser_root.locator(".admin-api-keys").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(".admin-config-area-card").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
  end

  it_behaves_like "having working core features"
end
