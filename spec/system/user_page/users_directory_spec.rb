# frozen_string_literal: true

describe "Users /u", type: :system do
  fab!(:user)

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

  describe "new directory item" do
    let!(:plugin) { Plugin::Instance.new }
    let!(:initial_directory_events) { [] }

    before do
      initial_directory_events.replace(DiscourseEvent.events["before_directory_refresh"].to_a)
      DB.exec("ALTER TABLE directory_items ADD COLUMN IF NOT EXISTS links integer")
    end

    after do
      DiscourseEvent.events["before_directory_refresh"].delete(
        (DiscourseEvent.events["before_directory_refresh"].to_a - initial_directory_events).last,
      )
      DB.exec("ALTER TABLE directory_items DROP COLUMN IF EXISTS links")
    end

    it "shows the directory column with the appropriate label" do
      plugin.add_directory_column(
        "links",
        query: "SELECT id, RANDOM() AS random_number FROM users;",
      )
      DirectoryItem.refresh!
      DirectoryColumn.find_by(name: "links").update!(enabled: true)

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
          "Links",
        ],
      )
    end
  end
end
