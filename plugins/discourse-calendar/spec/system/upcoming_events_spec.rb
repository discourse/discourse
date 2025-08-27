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

  describe "basic functionality" do
    fab!(:event)

    it "displays events in the calendar" do
      upcoming_events.visit

      expect(upcoming_events).to have_content_in_calendar(event.post.topic.title)
    end
  end

  describe "event display and formatting" do
    describe "local time display" do
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

      it "shows local time when showLocalTime is enabled",
         timezone: "Australia/Brisbane",
         time: Time.utc(2025, 6, 2, 19, 00) do
        upcoming_events.visit
        upcoming_events.open_year_view

        first_item = upcoming_events.find_event_by_position(2)
        expect(upcoming_events.event_time_text(first_item)).to include("2:05am")
        expect(upcoming_events.event_title_text(first_item)).to eq(
          "Event with local time (Local time: 8:05am)",
        )

        second_item = upcoming_events.find_event_by_position(3)
        expect(upcoming_events.event_time_text(second_item)).to include("1:00pm")
        expect(upcoming_events.event_title_text(second_item)).to eq("Event without local time")

        third_item = upcoming_events.find_event_by_position(5)
        expect(upcoming_events.event_time_text(third_item)).to include("8:05am")
        expect(upcoming_events.event_title_text(third_item)).to eq(
          "Event with local time and same timezone than user",
        )
      end
    end

    describe "recurring events" do
      fab!(:event)

      before do
        event.update!(
          original_starts_at: Time.utc(2025, 3, 18, 13, 00),
          timezone: "Australia/Brisbane",
          recurrence: "every_week",
          recurrence_until: 21.days.from_now,
        )
      end

      it "displays recurring events until the specified end date",
         time: Time.utc(2025, 6, 2, 19, 00) do
        upcoming_events.visit

        upcoming_events.expect_event_count(4)
        upcoming_events.expect_event_at_position(event.post.topic.title, row: 2, col: 2)
        upcoming_events.expect_event_at_position(event.post.topic.title, row: 3, col: 2)
        upcoming_events.expect_event_at_position(event.post.topic.title, row: 4, col: 2)
      end
    end
  end

  describe "event filtering" do
    it "shows only events the user is attending when filtered",
       time: Time.utc(2025, 6, 2, 19, 00) do
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

      upcoming_events.expect_event_visible("Attending post event")
      upcoming_events.expect_event_visible("Non attending post event")

      upcoming_events.open_mine_events

      upcoming_events.expect_event_visible("Attending post event")
      upcoming_events.expect_event_not_visible("Non attending post event")
    end
  end

  describe "calendar navigation and views" do
    describe "navigation buttons" do
      describe "today button" do
        it "navigates to current date", time: Time.utc(2025, 6, 2, 19, 00) do
          visit("/upcoming-events/month/2025/8/1")

          upcoming_events.today

          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/6/2")
        end

        context "in different timezone", timezone: "Europe/London" do
          it "navigates to current date in day view", time: Time.utc(2025, 6, 2, 19, 00) do
            visit("/upcoming-events/day/2025/8/1")

            upcoming_events.today

            upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/6/2")
          end
        end
      end

      describe "next button" do
        it "navigates to next month" do
          visit("/upcoming-events/month/2025/8/1")

          upcoming_events.next

          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/9/1")
        end

        it "navigates to next week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.next

          upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/8/11")
        end

        context "in different timezone", timezone: "Europe/London" do
          it "navigates to next day" do
            visit("/upcoming-events/day/2025/8/4")

            upcoming_events.next

            upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/8/5")
          end

          it "navigates to next week" do
            visit("/upcoming-events/week/2025/8/4")

            upcoming_events.next

            upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/8/11")
          end
        end
      end

      describe "prev button" do
        it "navigates to previous day" do
          visit("/upcoming-events/day/2025/8/1")

          upcoming_events.prev

          upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/7/31")
        end

        it "navigates to previous month" do
          visit("/upcoming-events/month/2025/8/1")

          upcoming_events.prev

          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/7/1")
        end

        it "navigates to previous week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.prev

          upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/7/28")
        end

        context "in different timezone", timezone: "Europe/London" do
          it "navigates to previous day" do
            visit("/upcoming-events/day/2025/8/1")

            upcoming_events.prev

            upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/7/31")
          end

          it "navigates to previous month" do
            visit("/upcoming-events/month/2025/8/1")

            upcoming_events.prev

            upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/7/1")
          end

          it "navigates to previous week" do
            visit("/upcoming-events/week/2025/8/4")

            upcoming_events.prev

            upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/7/28")
          end
        end
      end
    end

    describe "view switching" do
      it "switching from month to week view keeps the same day" do
        visit("/upcoming-events/month/2025/9/16")

        upcoming_events.open_week_view

        upcoming_events.expect_content("Sep 15 – 21, 2025")
        upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/9/16")
      end
    end
  end
end
