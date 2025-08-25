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
      upcoming_events.open_year_view

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

  context "when changing view", time: Time.utc(2025, 8, 21, 14, 00) do
    it "displays the chosen view" do
      upcoming_events.visit

      expect(page).to have_content("August 2025")
      expect(page).to have_current_path("/upcoming-events/month/2025/8/21")

      upcoming_events.open_day_view

      expect(page).to have_content("August 1, 2025")
      expect(page).to have_current_path("/upcoming-events/day/2025/8/1")
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

  context "when navigating between dates" do
    context "when clicking today", time: Time.utc(2025, 6, 2, 19, 00) do
      it "shows the current date" do
        visit("/upcoming-events/month/2025/8/1")

        upcoming_events.today

        expect(page).to have_current_path("/upcoming-events/month/2025/6/2")

        context "when in a different timezone", timezone: "Europe/London" do
          it "also works" do
            visit("/upcoming-events/day/2025/8/1")

            upcoming_events.today

            expect(page).to have_current_path("/upcoming-events/day/2025/6/2")
          end
        end
      end
    end

    context "when clicking next" do
      it "shows the next month" do
        visit("/upcoming-events/month/2025/8/1")

        upcoming_events.next

        expect(page).to have_current_path("/upcoming-events/month/2025/9/1")
      end

      it "shows the next week" do
        visit("/upcoming-events/week/2025/8/4")

        upcoming_events.next

        expect(page).to have_current_path("/upcoming-events/week/2025/8/11")
      end

      context "when in a different timezone", timezone: "Europe/London" do
        it "shows the next day" do
          visit("/upcoming-events/day/2025/8/4")

          upcoming_events.next

          expect(page).to have_current_path("/upcoming-events/day/2025/8/5")
        end

        it "shows the next week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.next

          expect(page).to have_current_path("/upcoming-events/week/2025/8/11")
        end
      end
    end

    context "when clicking prev" do
      it "shows the prev day" do
        visit("/upcoming-events/day/2025/8/1")

        upcoming_events.prev

        expect(page).to have_current_path("/upcoming-events/day/2025/7/31")
      end

      it "shows the prev month" do
        visit("/upcoming-events/month/2025/8/1")

        upcoming_events.prev

        expect(page).to have_current_path("/upcoming-events/month/2025/7/1")
      end

      it "shows the prev week" do
        visit("/upcoming-events/week/2025/8/4")

        upcoming_events.prev

        expect(page).to have_current_path("/upcoming-events/week/2025/7/28")
      end

      context "when in a different timezone", timezone: "Europe/London" do
        it "shows the prev day" do
          visit("/upcoming-events/day/2025/8/1")

          upcoming_events.prev

          expect(page).to have_current_path("/upcoming-events/day/2025/7/31")
        end

        it "shows the prev month" do
          visit("/upcoming-events/month/2025/8/1")

          upcoming_events.prev

          expect(page).to have_current_path("/upcoming-events/month/2025/7/1")
        end

        it "shows the prev week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.prev

          expect(page).to have_current_path("/upcoming-events/week/2025/7/28")
        end
      end
    end
  end
end
