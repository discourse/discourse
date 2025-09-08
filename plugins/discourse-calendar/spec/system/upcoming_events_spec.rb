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
    it "displays events in the calendar", time: Time.utc(2025, 9, 10, 12, 0) do
      post =
        create_post(
          user: admin,
          category: Fabricate(:category),
          title: "A great event to join",
          raw: "[event  start=\"2025-09-11 08:05\" end=\"2025-09-11 10:05\"]\n[/event]",
        )

      upcoming_events.visit

      expect(upcoming_events).to have_content_in_calendar(post.topic.title)
    end
  end

  describe "event display and formatting" do
    before { admin.user_option.update!(timezone: "America/New_York") }

    describe "non-recurring events" do
      describe "with local time enabled" do
        it "displays event time in event timezone with (Local time) suffix",
           timezone: "Australia/Brisbane",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Local time event",
            raw:
              "[event showLocalTime=true timezone=CET start=\"2025-09-11 08:05\" end=\"2025-09-11 10:05\"]\n[/event]",
          )

          upcoming_events.visit
          upcoming_events.open_year_view

          expect(upcoming_events).to have_event_with_time(
            "Local time event (Local time)",
            "8:05am - 10:05am",
          )

          find("a", text: "Local time event (Local time)").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Thu, Sep 11 8:05 AM (CET) → 10:05 AM (CET)",
          )
        end
      end

      describe "without local time (UTC events)" do
        it "displays event time converted to user timezone",
           timezone: "Australia/Brisbane",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Event with UTC time",
            raw:
              "[event timezone=CET start=\"2025-09-11 19:00\" end=\"2025-09-11 21:00\"]\n[/event]",
          )

          upcoming_events.visit
          upcoming_events.open_year_view

          expect(upcoming_events).to have_event_with_time("Event with UTC time", "1:00pm - 3:00pm")

          find("a", text: "Event with UTC time").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Tomorrow 1:00 PM → 3:00 PM",
          )
        end
      end

      describe "with same timezone as user" do
        it "displays event time normally when event timezone matches user timezone",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Same timezone event",
            raw:
              "[event showLocalTime=true timezone=\"America/New_York\" start=\"2025-09-12 08:05\" end=\"2025-09-12 09:05\"]\n[/event]",
          )

          upcoming_events.visit
          upcoming_events.open_year_view

          expect(upcoming_events).to have_event_with_time("Same timezone event", "8:05am - 9:05am")

          find("a", text: "Same timezone event").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Fri, Sep 12 8:05 AM → 9:05 AM",
          )
        end
      end
    end

    describe "recurring events" do
      describe "with local time enabled" do
        it "displays multiple occurrences with correct local time",
           timezone: "Australia/Brisbane",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Recurring local event",
            raw:
              "[event recurrence=every_week showLocalTime=true timezone=CET start=\"2025-09-11 08:05\" end=\"2025-09-11 10:05\"]\n[/event]",
          )

          upcoming_events.visit
          upcoming_events.open_year_view

          expect(page).to have_css(
            "tr.fc-list-event:nth-child(2) .fc-list-event-time",
            text: "8:05am - 10:05am",
          )
          expect(page).to have_css(
            "tr.fc-list-event:nth-child(4) .fc-list-event-time",
            text: "8:05am - 10:05am",
          )

          find("tr.fc-list-event:nth-child(2) .fc-list-event-title a").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Thu, Sep 11 8:05 AM (CET) → 10:05 AM (CET)",
          )

          page.send_keys(:escape)

          find("tr.fc-list-event:nth-child(4) .fc-list-event-title a").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Thu, Sep 18 8:05 AM (CET) → 10:05 AM (CET)",
          )
        end
      end

      describe "without local time (UTC events)" do
        it "displays multiple occurrences converted to user timezone",
           timezone: "Australia/Brisbane",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Recurring UTC event",
            raw:
              "[event recurrence=every_week timezone=CET start=\"2025-09-11 19:00\" end=\"2025-09-11 20:00\"]\n[/event]",
          )
          upcoming_events.visit
          upcoming_events.open_year_view

          expect(page).to have_css(
            "tr.fc-list-event:nth-child(2) .fc-list-event-time",
            text: "1:00pm - 2:00pm",
          )
          expect(page).to have_css(
            "tr.fc-list-event:nth-child(4) .fc-list-event-time",
            text: "1:00pm - 2:00pm",
          )

          find(
            "tr.fc-list-event:nth-child(2) .fc-list-event-title a",
            text: "Recurring UTC event",
          ).click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Tomorrow 1:00 PM → 2:00 PM (New York)",
          )

          page.send_keys(:escape)

          find(
            "tr.fc-list-event:nth-child(4) .fc-list-event-title a",
            text: "Recurring UTC event",
          ).click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Thu, Sep 18 1:00 PM → 2:00 PM",
          )
        end
      end

      describe "with same timezone as user" do
        it "displays multiple occurrences without timezone conversion issues",
           timezone: "Australia/Brisbane",
           time: Time.utc(2025, 9, 10, 12, 0) do
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "Recurring same TZ event",
            raw:
              "[event recurrence=every_week showLocalTime=true timezone=\"America/New_York\" start=\"2025-09-12 08:05\" end=\"2025-09-12 10:05\"]\n[/event]",
          )

          upcoming_events.visit
          upcoming_events.open_year_view

          expect(page).to have_css(
            "tr.fc-list-event:nth-child(2) .fc-list-event-time",
            text: "8:05am - 10:05am",
          )
          expect(page).to have_css(
            "tr.fc-list-event:nth-child(4) .fc-list-event-time",
            text: "8:05am - 10:05am",
          )

          find("tr.fc-list-event:nth-child(2) .fc-list-event-title a").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Fri, Sep 12 8:05 AM → 10:05 AM (New York)",
          )

          page.send_keys(:escape)

          find("tr.fc-list-event:nth-child(4) .fc-list-event-title a").click

          expect(page).to have_css(
            ".event__section.event-dates",
            text: "Fri, Sep 19 8:05 AM → 10:05 AM",
          )
        end
      end
    end

    describe "recurring events" do
      it "displays recurring events until the specified end date",
         time: Time.utc(2025, 6, 2, 19, 00) do
        post =
          create_post(
            user: admin,
            category: Fabricate(:category),
            title: "A recurring post event",
            raw:
              "[event recurrenceUntil=\"#{30.days.from_now.iso8601}\" timezone=\"Australia\/Brisbane\" recurrence=\"every_week\" status=\"public\" start=\"2025-06-11 08:05\"]\n[/event]",
          )

        upcoming_events.visit

        upcoming_events.expect_event_count(4)
        upcoming_events.expect_event_at_position(post.topic.title, row: 3, col: 3)
        upcoming_events.expect_event_at_position(post.topic.title, row: 4, col: 3)
        upcoming_events.expect_event_at_position(post.topic.title, row: 5, col: 3)
        upcoming_events.expect_event_at_position(post.topic.title, row: 6, col: 3)
      end
    end
  end

  describe "event filtering" do
    it "loads the correct range of dates", time: Time.utc(2025, 9, 1, 12, 0) do
      create_post(
        user: admin,
        category: Fabricate(:category),
        title: "going to the zoo",
        raw:
          "[event start=\"2025-09-07 18:30\" status=\"public\" timezone=\"Europe/Prague\" end=\"2025-09-07 21:00\"]\n[/event]",
      )

      visit("/upcoming-events/week/2025/9/1")

      upcoming_events.expect_event_visible("zoo")
    end

    it "shows only events the user is attending when filtered",
       time: Time.utc(2025, 6, 2, 19, 00) do
      attending_event =
        create_post(
          user: admin,
          category: Fabricate(:category),
          title: "Attending post event",
          raw: "[event status=\"public\" start=\"2025-06-11 08:05\"]\n[/event]",
        )
      create_post(
        user: admin,
        category: Fabricate(:category),
        title: "Non attending post event",
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

          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/6/1")
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

          expect(page).to have_content("September 2025")
          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/9/1")
        end

        it "navigates to next week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.next

          expect(page).to have_content("Aug 11 – 17, 2025")
          upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/8/11")
        end

        context "in different timezone", timezone: "Europe/London" do
          it "navigates to next day" do
            visit("/upcoming-events/day/2025/8/4")

            upcoming_events.next

            expect(page).to have_content("August 5, 2025")
            upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/8/5")
          end

          it "navigates to next week" do
            visit("/upcoming-events/week/2025/8/4")

            upcoming_events.next

            expect(page).to have_content("Aug 11 – 17, 2025")
            upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/8/11")
          end
        end
      end

      describe "prev button" do
        it "navigates to previous day" do
          visit("/upcoming-events/day/2025/8/1")

          upcoming_events.prev

          expect(page).to have_content("July 31, 2025")
          upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/7/31")
        end

        it "navigates to previous month" do
          visit("/upcoming-events/month/2025/8/1")

          upcoming_events.prev

          expect(page).to have_content("July 2025")
          upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/7/1")
        end

        it "navigates to previous week" do
          visit("/upcoming-events/week/2025/8/4")

          upcoming_events.prev

          expect(page).to have_content("Jul 28 – Aug 3, 2025")
          upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/7/28")
        end

        context "in different timezone", timezone: "Europe/London" do
          it "navigates to previous day" do
            visit("/upcoming-events/day/2025/8/1")

            upcoming_events.prev

            expect(page).to have_content("July 31, 2025")
            upcoming_events.expect_to_be_on_path("/upcoming-events/day/2025/7/31")
          end

          it "navigates to previous month" do
            visit("/upcoming-events/month/2025/8/1")

            upcoming_events.prev

            expect(page).to have_content("July 2025")
            upcoming_events.expect_to_be_on_path("/upcoming-events/month/2025/7/1")
          end

          it "navigates to previous week" do
            visit("/upcoming-events/week/2025/8/4")

            upcoming_events.prev

            expect(page).to have_content("Jul 28 – Aug 3, 2025")
            upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/7/28")
          end
        end
      end

      describe "event duration display" do
        context "with recurring event" do
          it "displays longer events with appropriate visual height in time grid view",
             time: Time.utc(2025, 6, 2, 19, 00) do
            create_post(
              user: admin,
              category: Fabricate(:category),
              title: "This is a short meeting",
              raw:
                "[event recurrence=\"every_week\" start=\"2025-06-03 10:00\" end=\"2025-06-03 11:00\"]\n[/event]",
            )

            create_post(
              user: admin,
              category: Fabricate(:category),
              title: "This is a long workshop",
              raw:
                "[event recurrence=\"every_week\" start=\"2025-06-03 14:00\" end=\"2025-06-03 17:00\"]\n[/event]",
            )

            upcoming_events.visit
            visit("/upcoming-events/week/2025/6/2")

            expect(upcoming_events).to have_event_height("This is a short meeting", 47)
            expect(upcoming_events).to have_event_height("This is a long workshop", 143)
          end
        end

        context "with non recurring event" do
          it "displays longer events with appropriate visual height in time grid view",
             time: Time.utc(2025, 6, 2, 19, 00) do
            create_post(
              user: admin,
              category: Fabricate(:category),
              title: "This is a short meeting",
              raw: "[event start=\"2025-06-03 10:00\" end=\"2025-06-03 11:00\"]\n[/event]",
            )

            create_post(
              user: admin,
              category: Fabricate(:category),
              title: "This is a long workshop",
              raw: "[event start=\"2025-06-03 14:00\" end=\"2025-06-03 17:00\"]\n[/event]",
            )

            upcoming_events.visit
            visit("/upcoming-events/week/2025/6/2")

            expect(upcoming_events).to have_event_height("This is a short meeting", 47)
            expect(upcoming_events).to have_event_height("This is a long workshop", 143)
          end
        end
      end
    end

    describe "view switching" do
      it "switching from month to week view keeps the same day" do
        visit("/upcoming-events/month/2025/9/16")

        upcoming_events.open_week_view

        upcoming_events.expect_content("Sep 15 – 21, 2025")
        upcoming_events.expect_to_be_on_path("/upcoming-events/week/2025/9/15")
      end
    end
  end
end
