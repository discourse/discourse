# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:user, username: "bookmarkguy") }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is some post to bookmark") }
  fab!(:post2) { Fabricate(:post, topic: topic, raw: "Some interesting post content") }

  it "allows logged in user to create bookmarks with and without reminders" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = PageObjects::Pages::Topic.new
    expect(topic_page).to have_post_content(post)
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :bookmark)

    bookmark_modal = PageObjects::Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    expect(topic_page).to have_post_bookmarked(post)
    bookmark = Bookmark.find_by(bookmarkable: post, user: user)
    expect(bookmark.name).to eq("something important")

    topic_page.expand_post_actions(post2)
    topic_page.click_post_action_button(post2, :bookmark)

    bookmark_modal = PageObjects::Modals::Bookmark.new
    bookmark_modal.select_preset_reminder(:tomorrow)
    expect(topic_page).to have_post_bookmarked(post2)
    bookmark = Bookmark.find_by(bookmarkable: post2, user: user)
    expect(bookmark.reminder_at).not_to eq(nil)
    expect(bookmark.reminder_set_at).not_to eq(nil)
  end

  it "does not create a bookmark if the modal is closed with the cancel button" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = PageObjects::Pages::Topic.new
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :bookmark)

    bookmark_modal = PageObjects::Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.cancel

    expect(topic_page).not_to have_post_bookmarked(post)
    expect(Bookmark.exists?(bookmarkable: post, user: user)).to eq(false)
  end

  it "allows the topic to be bookmarked" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = PageObjects::Pages::Topic.new
    topic_page.click_topic_footer_button(:bookmark)

    bookmark_modal = PageObjects::Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    expect(topic_page).to have_topic_bookmarked
    bookmark = try_until_success do
      expect(Bookmark.exists?(bookmarkable: topic, user: user)).to eq(true)
    end
    expect(bookmark).not_to eq(nil)
  end
end
