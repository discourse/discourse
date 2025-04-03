# frozen_string_literal: true

describe "User activity bookmarks", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:bookmark_1) do
    Fabricate(
      :bookmark,
      user: current_user,
      name: "Bookmark 1",
      bookmarkable: Fabricate(:post, raw: "a nice event"),
    )
  end
  fab!(:bookmark_2) do
    Fabricate(
      :bookmark,
      user: current_user,
      name: "Bookmark 2",
      bookmarkable: Fabricate(:post, raw: "a pretty cat"),
    )
  end

  let(:user_activity_bookmarks) { PageObjects::Pages::UserActivityBookmarks.new }

  before do
    SearchIndexer.enable
    SearchIndexer.index(bookmark_1.bookmarkable, force: true)
    SearchIndexer.index(bookmark_2.bookmarkable, force: true)
    Fabricate(:topic_user, user: current_user, topic: bookmark_1.bookmarkable.topic)
    Fabricate(:topic_user, user: current_user, topic: bookmark_2.bookmarkable.topic)

    sign_in(current_user)
  end

  after { SearchIndexer.disable }

  it "can filter the list of bookmarks from the URL" do
    user_activity_bookmarks.visit(current_user, q: bookmark_1.bookmarkable.raw)

    expect(user_activity_bookmarks).to have_no_topic(bookmark_2.bookmarkable.topic)
    expect(user_activity_bookmarks).to have_topic(bookmark_1.bookmarkable.topic)
  end

  it "can filter the list of bookmarks" do
    user_activity_bookmarks.visit(current_user).search_for(bookmark_2.bookmarkable.raw)

    expect(user_activity_bookmarks).to have_no_topic(bookmark_1.bookmarkable.topic)
    expect(user_activity_bookmarks).to have_topic(bookmark_2.bookmarkable.topic)
  end

  it "can clear the query" do
    user_activity_bookmarks.visit(current_user).search_for(bookmark_2.bookmarkable.raw)

    expect(user_activity_bookmarks).to have_no_topic(bookmark_1.bookmarkable.topic)
    expect(user_activity_bookmarks).to have_topic(bookmark_2.bookmarkable.topic)

    user_activity_bookmarks.clear_query

    expect(user_activity_bookmarks).to have_topic(bookmark_1.bookmarkable.topic)
    expect(user_activity_bookmarks).to have_topic(bookmark_2.bookmarkable.topic)
  end

  it "can clear the query with backspace" do
    user_activity_bookmarks.visit(current_user, q: "dog")
    user_activity_bookmarks.clear_query_with_backspace
    expect(user_activity_bookmarks).to have_empty_search
  end
end
