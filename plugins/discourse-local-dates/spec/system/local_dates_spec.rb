# frozen_string_literal: true

describe "Local dates", type: :system, js: true do
  fab!(:topic) { Fabricate(:topic) }
  fab!(:user) { Fabricate(:user) }

  before { create_post(user: user, topic: topic, title: "Date range test post", raw: <<~RAW) }
        First option: [date=2022-12-15 time=14:19:00 timezone="Asia/Singapore"]
        Second option: [date=2022-12-15 time=01:20:00 timezone="Asia/Singapore"], or [date=2022-12-15 time=02:40:00 timezone="Asia/Singapore"]
        Third option: [date-range from=2022-12-15T11:25:00 to=2022-12-16T00:26:00 timezone="Asia/Singapore"] or [date-range from=2022-12-22T11:57:00 to=2022-12-23T11:58:00 timezone="Asia/Singapore"]
      RAW

  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "renders local dates and date ranges correctly" do
    using_browser_timezone("Asia/Singapore") do
      sign_in user

      topic_page.visit_topic(topic)

      expect(topic_page).to have_content(topic.title)

      post_dates = topic_page.find_all("span[data-date]")

      # Single date in a paragraph.
      #
      post_dates[0].click
      tippy_date = topic_page.find(".tippy-content .current .date-time")

      expect(tippy_date).to have_text("Thursday, December 15, 2022\n2:19 PM", exact: true)

      # Two single dates in the same paragraph.
      #
      post_dates[1].click
      tippy_date = topic_page.find(".tippy-content .current .date-time")

      expect(tippy_date).to have_text("Thursday, December 15, 2022\n1:20 AM", exact: true)

      post_dates[2].click
      tippy_date = topic_page.find(".tippy-content .current .date-time")

      expect(tippy_date).to have_text("Thursday, December 15, 2022\n2:40 AM", exact: true)

      # Two date ranges in the same paragraph.
      #
      post_dates[3].click
      tippy_date = topic_page.find(".tippy-content .current .date-time")

      expect(tippy_date).to have_text(
        "Thursday, December 15, 2022\n11:25 AM → 12:26 AM",
        exact: true,
      )

      post_dates[5].click
      tippy_date = topic_page.find(".tippy-content .current .date-time")

      expect(tippy_date).to have_text(
        "Thursday, December 22, 2022 11:57 AM → Friday, December 23, 2022 11:58 AM",
        exact: true,
      )
    end
  end
end
