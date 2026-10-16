# frozen_string_literal: true

describe "Tags index page" do
  fab!(:admin)
  fab!(:user)

  context "when visiting as a staff user" do
    it "shows the admin dropdown" do
      sign_in(admin)
      browser_page.goto("/tags").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".tags-admin-dropdown").filter(visible: true)).not_to have_count(
        0,
      )
    end
  end

  context "when visiting as a regular user" do
    it "does not show the admin dropdown" do
      sign_in(user)
      browser_page.goto("/tags").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_root.locator(".tags-index").filter(visible: true)).not_to have_count(0)
      expect(browser_root.locator(".tags-admin-dropdown").filter(visible: true)).to have_count(0)
    end
  end
end
