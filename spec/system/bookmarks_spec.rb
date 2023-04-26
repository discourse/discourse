# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:user) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is some post to bookmark") }
  fab!(:post2) { Fabricate(:post, topic: topic, raw: "Some interesting post content") }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }

  before { sign_in user }

  def visit_topic_and_open_bookmark_modal(post)
    topic_page.visit_topic(topic)
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :bookmark)
  end

  it "allows the user to create bookmarks with and without reminders" do
    visit_topic_and_open_bookmark_modal(post)

    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    expect(topic_page).to have_post_bookmarked(post)
    bookmark = Bookmark.find_by(bookmarkable: post, user: user)
    expect(bookmark.name).to eq("something important")
    expect(bookmark.reminder_at).to eq(nil)

    visit_topic_and_open_bookmark_modal(post2)

    bookmark_modal.select_preset_reminder(:tomorrow)
    expect(topic_page).to have_post_bookmarked(post2)
    bookmark = Bookmark.find_by(bookmarkable: post2, user: user)
    expect(bookmark.reminder_at).not_to eq(nil)
    expect(bookmark.reminder_set_at).not_to eq(nil)
  end

  it "does not create a bookmark if the modal is closed with the cancel button" do
    visit_topic_and_open_bookmark_modal(post)

    bookmark_modal.fill_name("something important")
    bookmark_modal.cancel

    expect(topic_page).not_to have_post_bookmarked(post)
    expect(Bookmark.exists?(bookmarkable: post, user: user)).to eq(false)
  end

  it "creates a bookmark if the modal is closed by clicking outside the modal window" do
    visit_topic_and_open_bookmark_modal(post)

    bookmark_modal.fill_name("something important")
    bookmark_modal.click_outside

    expect(topic_page).to have_post_bookmarked(post)
  end

  it "allows the topic to be bookmarked" do
    topic_page.visit_topic(topic)
    topic_page.click_topic_footer_button(:bookmark)

    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    expect(topic_page).to have_topic_bookmarked
    bookmark =
      try_until_success { expect(Bookmark.exists?(bookmarkable: topic, user: user)).to eq(true) }
    expect(bookmark).not_to eq(nil)
  end

  context "when the user has a bookmark auto_delete_preference" do
    before do
      user.user_option.update!(
        bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
      )
    end

    it "is respected when the user creates a new bookmark" do
      visit_topic_and_open_bookmark_modal(post)

      bookmark_modal.save
      expect(topic_page).to have_post_bookmarked(post)

      bookmark = Bookmark.find_by(bookmarkable: post, user: user)
      expect(bookmark.auto_delete_preference).to eq(
        Bookmark.auto_delete_preferences[:on_owner_reply],
      )
    end

    it "allows the user to choose a different auto delete preference for a bookmark" do
      visit_topic_and_open_bookmark_modal(post)

      bookmark_modal.save
      expect(topic_page).to have_post_bookmarked(post)

      bookmark = Bookmark.find_by(bookmarkable: post, user: user)
      expect(bookmark.auto_delete_preference).to eq(
        Bookmark.auto_delete_preferences[:on_owner_reply],
      )
    end
  end
end
