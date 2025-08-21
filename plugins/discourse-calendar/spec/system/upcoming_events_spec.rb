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

      expect(page).to have_css("#upcoming-events-calendar .fc", text: event.post.topic.title)
    end
  end

  context "when display events with showLocalTime" do
    before do
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

    it "shows the local time in the title",
       timezone: "Australia/Brisbane",
       time: Time.utc(2025, 6, 2, 19, 00) do
      upcoming_events.visit
      upcoming_events.open_year_list

      first_item = find(".fc-event:nth-child(2)")
      expect(first_item.find(".fc-list-event-time")).to have_text("2:05am")
      expect(first_item.find(".fc-list-event-title")).to have_text(
        "Event with local time (Local time: 8:05am)",
      )

      second_item = find(".fc-event:nth-child(3)")
      expect(second_item.find(".fc-list-event-time")).to have_text("1:00pm")
      expect(second_item.find(".fc-list-event-title")).to have_text("Event without local time")

      third_item = find(".fc-event:nth-child(5)")
      expect(third_item.find(".fc-list-event-time")).to have_text("8:05am")
      expect(third_item.find(".fc-list-event-title")).to have_text(
        "Event with local time and same timezone than user",
      )
    end
  end

  context "when filtering my events" do
    it "shows only the events the user is attending", time: Time.utc(2025, 6, 2, 19, 00) do
      attending_event =
        PostCreator.create!(
          admin,
          title: "attending post event",
          raw: "[event status=\"public\" start=\"2025-06-11 08:05\"]\n[/event]",
        )
      non_attending_event =
        PostCreator.create!(
          admin,
          title: "non attending post event",
          raw: "[event start=\"2025-06-12 08:05\"]\n[/event]",
        )
      DiscoursePostEvent::Event.find(attending_event.id).create_invitees(
        [{ user_id: admin.id, status: 0 }],
      )

      upcoming_events.visit

      expect(page).to have_css(".fc-event-title", text: "Attending post event")
      expect(page).to have_css(".fc-event-title", text: "Non attending post event")

      upcoming_events.open_mine_events

      expect(page).to have_css(".fc-event-title", text: "Attending post event")
      expect(page).to have_no_css(".fc-event-title", text: "Non attending post event")
    end
  end

  context "when changing view" do
    it "displays the chosen view" do
      upcoming_events.visit

      expect(page).to have_current_path(
        "/upcoming-events?end=2025-09-01&start=2025-08-01&view=dayGridMonth",
      )

      upcoming_events.open_year_list

      expect(page).to have_current_path(
        "/upcoming-events?end=2026-01-01&start=2025-01-01&view=listYear",
      )
    end
  end

  context "when event is recurring" do
    fab!(:event)

    before do
      event.update!(
        original_starts_at: Time.utc(2025, 3, 18, 13, 00),
        timezone: "Australia/Brisbane",
        recurrence: "every_week",
        recurrence_until: 21.days.from_now,
      )
    end

    it "respects the until date", time: Time.utc(2025, 6, 2, 19, 00) do
      upcoming_events.visit

      expect(page).to have_css(".fc-daygrid-event-harness", count: 4)
      expect(page).to have_css(
        ".fc tr:nth-child(2) td:nth-child(2) .fc-event-title",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc tr:nth-child(3) td:nth-child(2) .fc-event-title",
        text: event.post.topic.title,
      )
      expect(page).to have_css(
        ".fc tr:nth-child(4) td:nth-child(2) .fc-event-title",
        text: event.post.topic.title,
      )
    end
  end
end
