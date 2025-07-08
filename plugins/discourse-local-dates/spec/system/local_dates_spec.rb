# frozen_string_literal: true

describe "Local dates", type: :system do
  fab!(:topic)
  fab!(:current_user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:year) { Time.zone.now.year + 1 }
  let(:month) { Time.zone.now.month }
  let(:bookmark_modal) { PageObjects::Modals::Bookmark.new }
  let(:bookmark_menu) { PageObjects::Components::BookmarkMenu.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:insert_datetime_modal) { PageObjects::Modals::InsertDateTime.new }

  before do
    create_post(user: current_user, topic: topic, title: "Date range test post", raw: <<~RAW)
        First option: [date=#{year}-12-15 time=14:19:00 timezone="Asia/Singapore"]
        Second option: [date=#{year}-12-15 time=01:20:00 timezone="Asia/Singapore"], or [date=#{year}-12-15 time=02:40:00 timezone="Asia/Singapore"]
        Third option: [date-range from=#{year}-12-15T11:25:00 to=#{year}-12-16T00:26:00 timezone="Asia/Singapore"] or [date-range from=#{year}-12-22T11:57:00 to=#{year}-12-23T11:58:00 timezone="Asia/Singapore"]
      RAW
  end

  let(:topic_page) { PageObjects::Pages::Topic.new }

  def formatted_date_for_year(month, day)
    Date.parse("#{year}-#{month}-#{day}").strftime("%A, %B %-d, %Y")
  end

  it "renders local dates and date ranges correctly" do
    using_browser_timezone("Asia/Singapore") do
      sign_in current_user

      topic_page.visit_topic(topic)

      expect(topic_page).to have_content(topic.title)

      # Single date in a paragraph.
      #
      find("span[data-date]:nth-of-type(1)").click
      expect(page.find("[data-content] .current .date-time")).to have_text(
        "#{formatted_date_for_year(12, 15)}\n 2:19 PM",
        exact: true,
      )
      page.send_keys(:escape)

      # Two single dates in the same paragraph.
      #
      find("span[data-date]:nth-of-type(2)").click
      expect(page.find("[data-content] .current .date-time")).to have_text(
        "#{formatted_date_for_year(12, 15)}\n 1:20 AM",
        exact: true,
      )
      page.send_keys(:escape)

      find("span[data-date]:nth-of-type(3)").click
      expect(page.find("[data-content] .current .date-time")).to have_text(
        "#{formatted_date_for_year(12, 15)}\n 2:40 AM",
        exact: true,
      )
      page.send_keys(:escape)

      # Two date ranges in the same paragraph.
      #
      find("span[data-date]:nth-of-type(4)").click
      expect(page.find("[data-content] .current .date-time")).to have_text(
        "#{formatted_date_for_year(12, 15)}\n 11:25 AM → 12:26 AM",
        exact: true,
      )
      page.send_keys(:escape)

      find("span[data-date]:nth-of-type(6)").click
      expect(page.find("[data-content] .current .date-time")).to have_text(
        "#{formatted_date_for_year(12, 22)} 11:57 AM → #{formatted_date_for_year(12, 23)} 11:58 AM",
        exact: true,
      )
      page.send_keys(:escape)
    end
  end

  describe "insert modal" do
    let(:timezone) { "Australia/Brisbane" }

    before do
      current_user.user_option.update!(timezone: timezone)
      sign_in(current_user)
    end

    it "allows selecting a date without a time and inserts into the post" do
      topic_page.visit_topic_and_open_composer(topic)
      expect(topic_page).to have_expanded_composer
      find(".toolbar-menu__options-trigger").click
      page.find("button[data-name=local-dates]").click
      expect(insert_datetime_modal).to be_open
      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(16)
      insert_datetime_modal.click_primary_button
      expect(composer.composer_input.value).to have_content(
        "[date=#{Date.parse("#{year}-#{month}-16").strftime("%Y-%m-%d")} timezone=\"#{timezone}\"]",
      )
    end

    it "allows selecting a date with a time and inserts into the post" do
      topic_page.visit_topic_and_open_composer(topic)
      expect(topic_page).to have_expanded_composer
      find(".toolbar-menu__options-trigger").click
      page.find("button[data-name=local-dates]").click
      expect(insert_datetime_modal).to be_open
      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(16)
      insert_datetime_modal.calendar_date_time_picker.fill_time("11:45")
      insert_datetime_modal.click_primary_button

      expect(composer.composer_input.value).to have_content(
        "[date=#{Date.parse("#{year}-#{month}-16").strftime("%Y-%m-%d")} time=11:45:00 timezone=\"#{timezone}\"]",
      )
    end

    it "allows selecting a start date and time and an end date and time" do
      topic_page.visit_topic_and_open_composer(topic)
      expect(topic_page).to have_expanded_composer
      find(".toolbar-menu__options-trigger").click
      page.find("button[data-name=local-dates]").click
      expect(insert_datetime_modal).to be_open
      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(16)
      insert_datetime_modal.calendar_date_time_picker.fill_time("11:45")
      insert_datetime_modal.select_to

      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(23)
      insert_datetime_modal.calendar_date_time_picker.fill_time("12:45")

      insert_datetime_modal.click_primary_button
      expect(composer.composer_input.value).to have_content(
        "[date-range from=#{Date.parse("#{year}-#{month}-16").strftime("%Y-%m-%d")}T11:45:00 to=#{Date.parse("#{year}-#{month}-23").strftime("%Y-%m-%d")}T12:45:00 timezone=\"#{timezone}\"]",
      )
    end

    it "allows clearing the end date and time" do
      topic_page.visit_topic_and_open_composer(topic)

      expect(topic_page).to have_expanded_composer

      find(".toolbar-menu__options-trigger").click
      page.find("button[data-name=local-dates]").click

      expect(insert_datetime_modal).to be_open

      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(16)
      insert_datetime_modal.calendar_date_time_picker.fill_time("11:45")
      insert_datetime_modal.select_to
      insert_datetime_modal.calendar_date_time_picker.select_year(year)
      insert_datetime_modal.calendar_date_time_picker.select_day(23)
      insert_datetime_modal.calendar_date_time_picker.fill_time("12:45")
      insert_datetime_modal.delete_to
      insert_datetime_modal.click_primary_button

      expect(composer.composer_input.value).to have_content(
        "[date=#{Date.parse("#{year}-#{month}-16").strftime("%Y-%m-%d")} time=11:45:00 timezone=\"#{timezone}\"]",
      )
    end
  end

  describe "bookmarks" do
    before do
      current_user.user_option.update!(timezone: "Asia/Singapore")
      sign_in(current_user)
    end

    it "can use the post local date for a bookmark preset" do
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(topic.first_post)
      topic_page.click_post_action_button(topic.first_post, :bookmark)
      bookmark_menu.click_menu_option("custom")
      bookmark_modal.select_preset_reminder(:post_local_date)
      expect(topic_page).to have_post_bookmarked(topic.first_post)
      bookmark = Bookmark.find_by(bookmarkable: topic.first_post, user: current_user)
      expect(bookmark.reminder_at.to_s).to eq("#{year}-12-15 06:19:00 UTC")
    end

    it "does not allow using post dates in the past for a bookmark preset" do
      topic.first_post.update!(
        raw: 'First option: [date=1999-12-15 time=14:19:00 timezone="Asia/Singapore"]',
      )
      topic.first_post.rebake!
      topic_page.visit_topic(topic)
      topic_page.expand_post_actions(topic.first_post)
      topic_page.click_post_action_button(topic.first_post, :bookmark)
      bookmark_menu.click_menu_option("custom")
      expect(bookmark_modal).to be_open
      expect(bookmark_modal).to have_no_preset(:post_local_date)
    end
  end
end
