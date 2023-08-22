# frozen_string_literal: true

describe "User selector", type: :system do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:user) { with_search_indexer_enabled { Fabricate(:user, username: "someone") } }

  before do
    current_user.activate
    sign_in(current_user)
  end

  context "when autocompleting a username" do
    it "correctly shows the user" do
      visit("/t/-/#{topic.id}")
      find(".btn-primary.create").click
      find(".d-editor-input").fill_in(with: "Hello @som")

      within(".autocomplete.ac-user") do |el|
        expect(el).to have_selector(".selected .avatar[title=someone]")
        expect(el.find(".selected .username")).to have_content("someone")
      end
    end
  end

  context "when autocompleting a group" do
    it "correctly shows the user" do
      visit("/t/-/#{topic.id}")
      find(".btn-primary.create").click
      find(".d-editor-input").fill_in(with: "Hello @adm")

      within(".autocomplete.ac-user") do |el|
        expect(el).to have_selector(".selected .d-icon-users")
        expect(el.find(".selected .username")).to have_content("admins")
      end
    end
  end
end
