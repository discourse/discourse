# frozen_string_literal: true

describe "User selector" do
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user, :admin)
  fab!(:user) { with_search_indexer_enabled { Fabricate(:user, username: "someone") } }

  before do
    current_user.activate
    sign_in(current_user)
  end

  context "when autocompleting a username" do
    it "correctly shows the user" do
      browser_page.goto("/t/-/#{topic.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".btn-primary.create").filter(visible: true).click
      browser_root.locator(".d-editor-input").filter(visible: true).press_sequentially("Hello @som")

      within_browser(browser_root.locator(".autocomplete.ac-user").filter(visible: true)) do |el|
        expect(
          el.locator(".selected .avatar[title=someone]").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        expect(
          el.locator(".selected .username").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(browser_text_pattern("someone"), useInnerText: true)
      end
    end
  end

  context "when autocompleting a group" do
    it "correctly shows the user" do
      browser_page.goto("/t/-/#{topic.id}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      browser_root.locator(".btn-primary.create").filter(visible: true).click
      browser_root.locator(".d-editor-input").filter(visible: true).press_sequentially("Hello @adm")

      within_browser(browser_root.locator(".autocomplete.ac-user").filter(visible: true)) do |el|
        expect(
          el.locator(".selected .d-icon-users").filter(visible: true),
        ).not_to PlaywrightMatchers.have_count(0)
        expect(
          el.locator(".selected .username").filter(visible: true),
        ).to PlaywrightMatchers.contain_text(browser_text_pattern("admins"), useInnerText: true)
      end
    end
  end
end
