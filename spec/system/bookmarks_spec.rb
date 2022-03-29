# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:user, username: "bookmarkguy") }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is some post to bookmark") }

  before do
    setup_system_test
    post.rebake!
  end

  it "does not allow anon to create bookmarks" do
    visit "/t/#{topic.id}"
    expect(page).to have_content("This is some post to bookmark")
    expect(page).not_to have_css("#post_#{post.id} .show-more-actions")
  end

  it "allows logged in user to create bookmarks" do
    visit "/session/#{user.encoded_username}/become"
    visit "/t/#{topic.id}"
    expect(page).to have_content("This is some post to bookmark")
    find("#post_#{post.post_number} .show-more-actions").click
    find(".bookmark.with-reminder").click
    fill_in "bookmark-name", with: "something important"
    find("#save-bookmark").click
    expect(page).to have_css(".bookmark.with-reminder.bookmarked")
    bookmark = Bookmark.find_by(post: post, user: user)
    expect(bookmark.name).to eq("something important")
  end
end
