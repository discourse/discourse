# frozen_string_literal: true

RSpec.describe "Opening a fully read nested topic bookmark" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:topic) { Fabricate(:topic, user: user) }
  fab!(:op) { Fabricate(:post, topic: topic, user: user) }

  let(:nested_view) { PageObjects::Pages::NestedView.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:user_menu) { PageObjects::Components::UserMenu.new }
  let(:bookmark_menu) { PageObjects::Components::BookmarkMenu.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_default_sort = "old"
    Fabricate(:nested_topic, topic: topic)
    sign_in(user)
  end

  it "restores the topic and its bookmark after navigating through latest" do
    nested_view.visit_nested(topic)
    topic_page.click_topic_bookmark_button
    expect(topic_page).to have_topic_bookmarked(topic)
    bookmark = Bookmark.find_by!(bookmarkable: topic, user: user)
    TopicUser.find_by!(topic: topic, user: user).update!(last_read_post_number: op.post_number)

    nested_view.route_to("/latest")
    expect(nested_view).to have_no_nested_view
    user_menu.open.click_bookmarks_tab
    user_menu.click_topic_bookmark(topic)

    expect(nested_view).to have_nested_view
    expect(topic_page).to have_topic_bookmarked(topic)
    topic_page.click_topic_bookmark_button
    bookmark_menu.click_menu_option("edit")
    expect(bookmark_modal).to be_editing_id(bookmark.id)

    nested_view.visit_nested_context(topic, post_number: 2)
    expect(nested_view).to have_nested_view
    expect(nested_view).to have_no_context_view
    expect(topic_page).to have_topic_bookmarked(topic)
  end

  it "focuses the last visible reply when a flat link points beyond the end" do
    reply = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)

    nested_view.visit_nested_context(topic, post_number: reply.post_number + 1)

    expect(nested_view).to have_context_view
    expect(nested_view).to have_highlighted_post(reply)
  end
end
