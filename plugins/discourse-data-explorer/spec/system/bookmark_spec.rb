# frozen_string_literal: true

describe "Bookmarking reports attached to a group", type: :system do
  fab!(:current_user) { Fabricate(:admin) }
  fab!(:query_1) do
    Fabricate(
      :query,
      name: "My query",
      description: "Test query",
      sql: "SELECT * FROM users",
      user: current_user,
    )
  end
  fab!(:group) { Fabricate(:group, name: "group") }
  fab!(:group_user) { Fabricate(:group_user, user: current_user, group: group) }
  fab!(:query_group_1) { Fabricate(:query_group, query: query_1, group: group) }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }

  before do
    SiteSetting.data_explorer_enabled = true
    sign_in(current_user)
  end

  it "allows the user to bookmark a group report" do
    visit("/g/group/reports/#{query_1.id}")
    find(".query-group-bookmark").click
    expect(bookmark_modal).to be_open
    bookmark_modal.click_primary_button
    expect(page).to have_css(".query-group-bookmark.bookmarked")
    expect(Bookmark.exists?(user: current_user, bookmarkable: query_group_1)).to eq(true)
  end

  it "allows the user to edit and delete a group report bookmark" do
    bookmark =
      Fabricate(:bookmark, user: current_user, bookmarkable: query_group_1, reminder_at: nil)

    visit("/g/group/reports/#{query_1.id}")
    find(".query-group-bookmark").click
    expect(bookmark_modal).to be_open
    bookmark_modal.fill_name("Remember this query")
    bookmark_modal.click_primary_button
    expect(bookmark_modal).to be_closed
    expect(bookmark.reload.name).to eq("Remember this query")

    find(".query-group-bookmark").click
    expect(bookmark_modal).to be_open
    bookmark_modal.delete
    expect(bookmark_modal).to be_closed
    expect(page).not_to have_css(".query-group-bookmark.bookmarked")
    expect(Bookmark.exists?(user: current_user, bookmarkable: query_group_1)).to eq(false)
  end

  it "shows bookmarked group reports in the user bookmark list" do
    bookmark = Fabricate(:bookmark, user: current_user, bookmarkable: query_group_1)
    visit("/u/#{current_user.username_lower}/activity/bookmarks")
    expect(page.find(".bookmark-list")).to have_content("My query")
  end
end
