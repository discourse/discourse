# frozen_string_literal: true

describe "Upcoming Events", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:category)

  let(:composer) { PageObjects::Components::Composer.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:upcoming_events) { PageObjects::Pages::DiscourseCalendar::UpcomingEvents.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    sign_in(admin)
  end

  context "when user is signed in" do
    fab!(:event)

    before { sign_in(admin) }

    it "shows the upcoming events" do
      upcoming_events.visit

      expect(page).to have_css(
        "#upcoming-events-calendar .fc-event-container",
        text: event.post.topic.title,
      )
    end
  end

  context "when display events with showLocalTime" do
    let(:fixed_time) { Time.utc(2025, 6, 2, 19, 00) }

    before do
      freeze_time(fixed_time)

      admin.user_option.update!(timezone: "America/New_York")

      PostCreator.create!(
        admin,
        title: "Event with local time",
        raw: "[event showLocalTime=true timezone=CET start=\"2025-09-11 08:05\"]\n[/event]",
      )

      PostCreator.create!(
        admin,
        title: "Event without local time",
        raw: "[event timezone=CET start=\"2025-09-11 19:00\"]\n[/event]",
      )

      PostCreator.create!(
        admin,
        title: "Event with local time and same timezone than user",
        raw:
          "[event showLocalTime=true timezone=\"America/New_York\" start=\"2025-09-12 08:05\"]\n[/event]",
      )
    end

    it "shows the local time in the title", timezone: "Australia/Brisbane" do
      page.driver.with_playwright_page { |pw_page| pw_page.clock.set_fixed_time(fixed_time) }
      upcoming_events.visit
      upcoming_events.open_year_list

      first_item = find(".fc-list-item:nth-child(2)")
      expect(first_item.find(".fc-list-item-time")).to have_text("2:05am")
      expect(first_item.find(".fc-list-item-title")).to have_text(
        "Event with local time (Local time: 8:05am)",
      )

      second_item = find(".fc-list-item:nth-child(3)")
      expect(second_item.find(".fc-list-item-time")).to have_text("1:00pm")
      expect(second_item.find(".fc-list-item-title")).to have_text("Event without local time")

      third_item = find(".fc-list-item:nth-child(5)")
      expect(third_item.find(".fc-list-item-time")).to have_text("8:05am")
      expect(third_item.find(".fc-list-item-title")).to have_text(
        "Event with local time and same timezone than user",
      )
    end
  end

  context "when event is recurring" do
    fab!(:event)

    let(:fixed_time) { Time.utc(2025, 6, 2, 19, 00) }

    before do
      freeze_time(fixed_time)

      event.update!(
        original_starts_at: Time.utc(2025, 3, 18, 13, 00),
        timezone: "Australia/Brisbane",
        recurrence: "every_week",
        recurrence_until: 21.days.from_now,
      )
    end

    it "respects the until date" do
      page.driver.with_playwright_page { |pw_page| pw_page.clock.set_fixed_time(fixed_time) }
      upcoming_events.visit

      expect(page).to have_css(".fc-day-grid-event", count: 3)
      expect(page).to have_css(
        ".fc-week:nth-child(2) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc-week:nth-child(3) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc-week:nth-child(4) .fc-content-skeleton:nth-child(2)",
        text: event.post.topic.title,
      )
    end
  end
end
