# frozen_string_literal: true

module Pages
  class Topic
    include Capybara::DSL

    POST_CLASSES = {
      show_more_actions: ".show-more-actions"
    }

    POST_ACTION_BUTTON_CLASSES = {
      bookmark: ".bookmark.with-reminder"
    }

    def has_post_content?(post)
      post_by_number(post).has_content? post.raw
    end

    def has_post_more_actions?(post)
      post_by_number(post).has_css?(POST_CLASSES[:show_more_actions])
    end

    def post_bookmarked?(post)
      post_by_number(post).has_css?(POST_ACTION_BUTTON_CLASSES[:bookmark] + ".bookmarked")
    end

    def expand_post_actions(post)
      post_by_number(post).find(POST_CLASSES[:show_more_actions]).click
    end

    def click_post_action_button(post, button)
      post_by_number(post).find(POST_ACTION_BUTTON_CLASSES[button]).click
    end

    def click_topic_footer_button(button)
      find_topic_footer_button(button).click
    end

    def topic_bookmarked?
      bookmark_button = find_topic_footer_button(:bookmark)
      bookmark_button.has_content?("Edit Bookmark")
      bookmark_button.has_css?(".bookmarked")
    end

    def find_topic_footer_button(button)
      find("#topic-footer-button-#{button}")
    end

    private

    def post_by_number(post)
      find("#post_#{post.post_number}")
    end
  end
end

module Modals
  class ModalBase
    def close
      find(".modal-close").click
    end

    def cancel
      find(".d-modal-cancel").click
    end
  end

  class Bookmark < ModalBase
    include Capybara::DSL

    def fill_name(name)
      fill_in "bookmark-name", with: name
    end

    def select_preset_reminder(identifier)
      find("#tap_tile_#{identifier}").click
    end

    def save
      find("#save-bookmark").click
    end
  end
end

describe "Bookmarking posts and topics", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:user, username: "bookmarkguy") }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is some post to bookmark") }
  fab!(:post2) { Fabricate(:post, topic: topic, raw: "Some interesting post content") }

  before do
    SiteSetting.external_system_avatars_enabled = false
    setup_system_test
    post.rebake!
  end

  it "does not allow anon to create bookmarks" do
    visit "/t/#{topic.id}"

    topic_page = Pages::Topic.new
    expect(topic_page).to have_post_content(post)
    expect(topic_page).not_to have_post_more_actions(post)
  end

  it "allows logged in user to create bookmarks with and without reminders" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = Pages::Topic.new
    expect(topic_page).to have_post_content(post)
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :bookmark)

    bookmark_modal = Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    expect(topic_page.post_bookmarked?(post)).to eq(true)
    bookmark = Bookmark.find_by(post: post, user: user)
    expect(bookmark.name).to eq("something important")

    topic_page.expand_post_actions(post2)
    topic_page.click_post_action_button(post2, :bookmark)

    bookmark_modal = Modals::Bookmark.new
    bookmark_modal.select_preset_reminder(:tomorrow)
    expect(topic_page.post_bookmarked?(post2)).to eq(true)
    bookmark = Bookmark.find_by(post: post2, user: user)
    expect(bookmark.reminder_at).not_to eq(nil)
    expect(bookmark.reminder_set_at).not_to eq(nil)
  end

  it "does not create a bookmark if the modal is closed with the cancel button" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = Pages::Topic.new
    topic_page.expand_post_actions(post)
    topic_page.click_post_action_button(post, :bookmark)

    bookmark_modal = Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.cancel

    expect(topic_page.post_bookmarked?(post)).to eq(false)
    expect(Bookmark.exists?(post: post, user: user)).to eq(false)
  end

  it "allows the topic to be bookmarked" do
    sign_in user
    visit "/t/#{topic.id}"
    topic_page = Pages::Topic.new
    topic_page.click_topic_footer_button(:bookmark)

    bookmark_modal = Modals::Bookmark.new
    bookmark_modal.fill_name("something important")
    bookmark_modal.save

    topic_page.topic_bookmarked?
    bookmark = Bookmark.find_by(post: post, user: user)
    expect(bookmark.for_topic).to eq(true)
  end
end
