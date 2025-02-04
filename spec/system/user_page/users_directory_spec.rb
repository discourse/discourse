# frozen_string_literal: true

describe "Users directory", type: :system do
  fab!(:user)
  let!(:initial_directory_events) { [] }

  before { Array.new(DirectoryItemsController::PAGE_SIZE + 10) { Fabricate(:user) } }

  describe "shows a table of users" do
    it "renders successfully for a logged-in user" do
      DirectoryItem.refresh!
      sign_in(user)

      visit("/u")

      expect(page).to have_css(".users-directory")
      expect(page).not_to have_css(".spinner")
      header_texts =
        page
          .all(".directory-table__column-header .header-contents")
          .map { |element| element.text.strip }

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
      visit("/u")

      expect(page).to have_css(".users-directory")
      expect(page).not_to have_css(".spinner")
      header_texts =
        page
          .all(".directory-table__column-header .header-contents")
          .map { |element| element.text.strip }

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
