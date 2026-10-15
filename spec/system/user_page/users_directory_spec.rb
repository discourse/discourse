# frozen_string_literal: true

describe "Users directory" do
  fab!(:user)
  let!(:initial_directory_events) { [] }

  before { Array.new(DirectoryItemsController::PAGE_SIZE + 10) { Fabricate(:user) } }

  describe "shows a table of users" do
    it "renders successfully for a logged-in user" do
      DirectoryItem.refresh!
      sign_in(user)

      browser_page.goto("/u").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".users-directory").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".spinner").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      header_texts =
        browser_root
          .locator(".directory-table__column-header .header-contents")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip.strip }

      expect(header_texts).to eq(
        [
          "Username",
          "Received",
          "Given",
          "Topics Created",
          "Replies Posted",
          "Topics Viewed",
          "Posts Read",
          "Days Visited",
        ],
      )
    end

    it "renders successfully for an anonymous user" do
      DirectoryItem.refresh!
      browser_page.goto("/u").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(
        browser_root.locator(".users-directory").filter(visible: true),
      ).not_to PlaywrightMatchers.have_count(0)
      expect(
        browser_root.locator(".spinner").filter(visible: true),
      ).to PlaywrightMatchers.have_count(0)
      header_texts =
        browser_root
          .locator(".directory-table__column-header .header-contents")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .map { |element| element.inner_text.strip.strip }

      expect(header_texts).to eq(
        [
          "Username",
          "Received",
          "Given",
          "Topics Created",
          "Replies Posted",
          "Topics Viewed",
          "Posts Read",
          "Days Visited",
        ],
      )
    end
  end
end
