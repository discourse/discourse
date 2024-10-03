# frozen_string_literal: true

describe "Bookmarking posts and topics", type: :system do
  fab!(:topic)
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post) { Fabricate(:post, topic: topic, raw: "This is some post to bookmark") }
  fab!(:post_2) { Fabricate(:post, topic: topic, raw: "Some interesting post content") }

  let(:timezone) { "Australia/Brisbane" }
  let(:cdp) { PageObjects::CDP.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }
  let(:bookmark_menu) { PageObjects::Components::BookmarkMenu.new }

  before do
    current_user.user_option.update!(timezone: timezone)
    sign_in(current_user)
  end

  def visit_topic_and_open_bookmark_menu(post, expand_actions: true)
    topic_page.visit_topic(topic)
    open_bookmark_menu(post, expand_actions: expand_actions)
  end

  def open_bookmark_menu(post, expand_actions: true)
    topic_page.expand_post_actions(post) if expand_actions
    topic_page.click_post_action_button(post, :bookmark)
  end

  it "creates a bookmark on the post as soon as the bookmark button is clicked" do
    visit_topic_and_open_bookmark_menu(post)

    expect(bookmark_menu).to be_open
    expect(page).to have_content(I18n.t("js.bookmarks.bookmarked_success"))
    expect(topic_page).to have_post_bookmarked(post, with_reminder: false)
    try_until_success(frequency: 0.5) do
      expect(Bookmark.find_by(bookmarkable: post, user: current_user)).to be_truthy
    end
  end

  it "updates the created bookmark with a selected reminder option from the bookmark menu" do
    visit_topic_and_open_bookmark_menu(post)

    expect(bookmark_menu).to be_open
    expect(page).to have_content(I18n.t("js.bookmarks.bookmarked_success"))

    bookmark_menu.click_menu_option("tomorrow")

    expect(topic_page).to have_post_bookmarked(post, with_reminder: true)
    expect(page).to have_no_css(".bookmark-menu-content.-expanded")
    try_until_success(frequency: 0.5) do
      expect(Bookmark.find_by(bookmarkable: post, user: current_user).reminder_at).not_to be_blank
    end
  end

  it "can set a reminder from the bookmark modal using the custom bookmark menu option" do
    visit_topic_and_open_bookmark_menu(post)
    bookmark_menu.click_menu_option("custom")
    bookmark_modal.select_preset_reminder(:tomorrow)
    expect(topic_page).to have_post_bookmarked(post, with_reminder: true)
    try_until_success(frequency: 0.5) do
      expect(Bookmark.find_by(bookmarkable: post, user: current_user).reminder_at).not_to be_blank
    end
  end

  it "allows choosing a different auto_delete_preference to the user preference and remembers it when reopening the modal" do
    current_user.user_option.update!(
      bookmark_auto_delete_preference: Bookmark.auto_delete_preferences[:on_owner_reply],
    )
    visit_topic_and_open_bookmark_menu(post_2)
    bookmark_menu.click_menu_option("custom")
    expect(bookmark_modal).to be_open

    # NOTE: (martin) Not sure why, but I need to click this twice for the panel to open :/
    bookmark_modal.open_options_panel
    bookmark_modal.open_options_panel

    expect(bookmark_modal).to have_auto_delete_preference(
      Bookmark.auto_delete_preferences[:on_owner_reply],
    )
    bookmark_modal.select_auto_delete_preference(Bookmark.auto_delete_preferences[:clear_reminder])
    bookmark_modal.save
    expect(topic_page).to have_post_bookmarked(post_2, with_reminder: false)
    topic_page.click_post_action_button(post_2, :bookmark)
    bookmark_menu.click_menu_option("edit")
    expect(bookmark_modal).to have_open_options_panel
    expect(bookmark_modal).to have_auto_delete_preference(
      Bookmark.auto_delete_preferences[:clear_reminder],
    )
  end

  describe "topic level bookmarks" do
    it "allows the topic to be bookmarked" do
      topic_page.visit_topic(topic)
      topic_page.click_topic_bookmark_button
      expect(topic_page).to have_topic_bookmarked(topic)
      expect(Bookmark.exists?(bookmarkable: topic, user: current_user)).to be_truthy
    end

    it "opens the edit bookmark modal from the topic bookmark button and saves edits" do
      bookmark = Fabricate(:bookmark, bookmarkable: topic, user: current_user)
      topic_page.visit_topic(topic)
      topic_page.click_topic_bookmark_button
      bookmark_menu.click_menu_option("edit")
      expect(bookmark_modal).to be_open
      expect(bookmark_modal).to be_editing_id(bookmark.id)
      bookmark_modal.fill_name("something important")
      bookmark_modal.click_primary_button

      try_until_success(frequency: 0.5) do
        expect(bookmark.reload.name).to eq("something important")
      end
    end

    it "allows to set a relative time" do
      bookmark = Fabricate(:bookmark, bookmarkable: topic, user: current_user)
      topic_page.visit_topic(topic)
      topic_page.click_topic_bookmark_button
      bookmark_menu.click_menu_option("edit")
      bookmark_modal.select_relative_time_duration(10)
      bookmark_modal.select_relative_time_interval("days")

      expect(bookmark_modal.custom_time_picker.value).to eq(
        bookmark.reminder_at_in_zone(timezone).strftime("%H:%M"),
      )
    end
  end

  describe "editing existing bookmarks" do
    fab!(:bookmark) do
      Fabricate(
        :bookmark,
        bookmarkable: post_2,
        user: current_user,
        name: "test name",
        reminder_at: 10.days.from_now,
      )
    end

    it "prefills the name of the bookmark and the custom reminder date and time" do
      visit_topic_and_open_bookmark_menu(post_2, expand_actions: false)
      bookmark_menu.click_menu_option("edit")
      expect(bookmark_modal).to have_open_options_panel
      expect(bookmark_modal.name.value).to eq("test name")
      expect(bookmark_modal.existing_reminder_alert).to have_content(
        bookmark_modal.existing_reminder_alert_message(bookmark),
      )
      expect(bookmark_modal.custom_date_picker.value).to eq(
        bookmark.reminder_at_in_zone(timezone).strftime("%Y-%m-%d"),
      )
      expect(bookmark_modal.custom_time_picker.value).to eq(
        bookmark.reminder_at_in_zone(timezone).strftime("%H:%M"),
      )
      expect(bookmark_modal).to have_active_preset("custom")
    end

    it "can delete the bookmark" do
      visit_topic_and_open_bookmark_menu(post_2, expand_actions: false)
      bookmark_menu.click_menu_option("edit")
      bookmark_modal.delete
      bookmark_modal.confirm_delete
      expect(topic_page).to have_no_post_bookmarked(post_2)
    end

    it "can delete the bookmark from within the menu" do
      visit_topic_and_open_bookmark_menu(post_2, expand_actions: false)
      bookmark_menu.click_menu_option("delete")
      expect(topic_page).to have_no_post_bookmarked(post_2)
    end

    it "does not save edits when pressing cancel" do
      visit_topic_and_open_bookmark_menu(post_2, expand_actions: false)
      bookmark_menu.click_menu_option("edit")
      bookmark_modal.fill_name("something important")
      bookmark_modal.cancel
      topic_page.click_post_action_button(post_2, :bookmark)
      bookmark_menu.click_menu_option("edit")
      expect(bookmark_modal.name.value).to eq("something important")
      expect(bookmark.reload.name).to eq("test name")
    end
  end
end
