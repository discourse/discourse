# frozen_string_literal: true

describe "Upcoming Events", type: :system do
  fab!(:admin)

  let(:upcoming_events) { PageObjects::Pages::DiscourseCalendar::UpcomingEvents.new }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.calendar_upcoming_events_default_view = "month"
    sign_in(admin)
  end

  def create_event(title:, start:, end_time: nil, **options)
    attrs = ["start=\"#{start}\""]
    attrs << "end=\"#{end_time}\"" if end_time
    attrs << "timezone=\"#{options[:timezone]}\"" if options[:timezone]
    attrs << "recurrence=#{options[:recurrence]}" if options[:recurrence]
    attrs << "recurrenceUntil=\"#{options[:recurrence_until]}\"" if options[:recurrence_until]
    attrs << "showLocalTime=#{options[:show_local_time]}" if options[:show_local_time]
    attrs << "status=\"#{options[:status]}\"" if options[:status]

    create_post(
      user: admin,
      category: Fabricate(:category),
      title:,
      raw: "[event #{attrs.join(" ")}]\n[/event]",
    )
  end

  describe "basic functionality" do
    it "displays events in the calendar", time: Time.utc(2025, 9, 10, 12, 0) do
      post =
        create_event(
          title: "Company planning meeting for Q4",
          start: "2025-09-11 08:05",
          end_time: "2025-09-11 10:05",
        )

      upcoming_events.visit

      expect(upcoming_events).to have_content_in_calendar(post.topic.title)
    end
  end

  describe "event display and formatting" do
    # To avoid flaky tests, each test sets the profile timezone to match
    # the browser timezone (set via `timezone:` metadata).

    describe "with showLocalTime enabled" do
      it "displays time in event timezone with suffix",
         timezone: "Australia/Brisbane",
         time: Time.utc(2025, 9, 10, 12, 0) do
        admin.user_option.update!(timezone: "Australia/Brisbane")

        create_event(
          title: "European conference call with partners",
          start: "2025-09-11 08:05",
          end_time: "2025-09-11 10:05",
          timezone: "CET",
          show_local_time: true,
        )

        upcoming_events.visit
        upcoming_events.open_year_view

        expect(upcoming_events).to have_event_with_time(
          "European conference call with partners (Local time)",
          "8:05am - 10:05am",
        )

        upcoming_events.click_event("European conference call with partners (Local time)")

        expect(upcoming_events).to have_event_dates("Thu, Sep 11 8:05 AM (CET) → 10:05 AM (CET)")
      end
    end

    describe "without showLocalTime" do
      it "converts time to browser timezone",
         timezone: "Australia/Brisbane",
         time: Time.utc(2025, 9, 10, 12, 0) do
        admin.user_option.update!(timezone: "Australia/Brisbane")

        create_event(
          title: "Berlin team sync meeting",
          start: "2025-09-11 19:00",
          end_time: "2025-09-11 21:00",
          timezone: "CET",
        )

        upcoming_events.visit
        upcoming_events.open_year_view

        # 19:00 CET = 03:00+1 Brisbane
        expect(upcoming_events).to have_event_with_time(
          "Berlin team sync meeting",
          "3:00am - 5:00am",
        )

        upcoming_events.click_event("Berlin team sync meeting")

        expect(upcoming_events).to have_event_dates("Friday at 3:00 AM → 5:00 AM (Brisbane)")
      end
    end

    describe "when event timezone matches user timezone" do
      it "displays time without conversion",
         timezone: "America/New_York",
         time: Time.utc(2025, 9, 10, 12, 0) do
        admin.user_option.update!(timezone: "America/New_York")

        create_event(
          title: "New York office standup meeting",
          start: "2025-09-12 08:05",
          end_time: "2025-09-12 09:05",
          timezone: "America/New_York",
          show_local_time: true,
        )

        upcoming_events.visit
        upcoming_events.open_year_view

        expect(upcoming_events).to have_event_with_time(
          "New York office standup meeting",
          "8:05am - 9:05am",
        )

        upcoming_events.click_event("New York office standup meeting")

        expect(upcoming_events).to have_event_dates("Fri, Sep 12 8:05 AM → 9:05 AM")
      end
    end

    describe "recurring events" do
      it "displays multiple occurrences with showLocalTime",
         timezone: "Australia/Brisbane",
         time: Time.utc(2025, 9, 10, 12, 0) do
        admin.user_option.update!(timezone: "Australia/Brisbane")

        create_event(
          title: "Weekly European team standup",
          start: "2025-09-11 08:05",
          end_time: "2025-09-11 10:05",
          timezone: "CET",
          recurrence: "every_week",
          show_local_time: true,
        )

        upcoming_events.visit
        upcoming_events.open_year_view

        expect(upcoming_events).to have_recurring_event_time(
          occurrence: 1,
          time: "8:05am - 10:05am",
        )
        expect(upcoming_events).to have_recurring_event_time(
          occurrence: 2,
          time: "8:05am - 10:05am",
        )

        upcoming_events.click_recurring_event(occurrence: 1)

        expect(upcoming_events).to have_event_dates("Thu, Sep 11 8:05 AM (CET) → 10:05 AM (CET)")

        upcoming_events.close_event_modal
        upcoming_events.click_recurring_event(occurrence: 2)

        expect(upcoming_events).to have_event_dates("Thu, Sep 18 8:05 AM (CET) → 10:05 AM (CET)")
      end

      it "displays multiple occurrences converted to browser timezone",
         timezone: "Australia/Brisbane",
         time: Time.utc(2025, 9, 10, 12, 0) do
        admin.user_option.update!(timezone: "Australia/Brisbane")

        create_event(
          title: "Weekly Berlin evening sync",
          start: "2025-09-11 19:00",
          end_time: "2025-09-11 20:00",
          timezone: "CET",
          recurrence: "every_week",
        )

        upcoming_events.visit
        upcoming_events.open_year_view

        # 19:00 CET = 03:00+1 Brisbane
        expect(upcoming_events).to have_recurring_event_time(occurrence: 1, time: "3:00am - 4:00am")
        expect(upcoming_events).to have_recurring_event_time(occurrence: 2, time: "3:00am - 4:00am")

        upcoming_events.click_recurring_event(occurrence: 1, title: "Weekly Berlin evening sync")

        expect(upcoming_events).to have_event_dates("Friday at 3:00 AM → 4:00 AM (Brisbane)")

        upcoming_events.close_event_modal
        upcoming_events.click_recurring_event(occurrence: 2, title: "Weekly Berlin evening sync")

        expect(upcoming_events).to have_event_dates("Fri, Sep 19 3:00 AM → 4:00 AM (Brisbane)")
      end

      it "respects recurrenceUntil", time: Time.utc(2025, 6, 2, 19, 00) do
        create_event(
          title: "Monthly book club with limited occurrences",
          start: "2025-06-11 08:05",
          timezone: "Australia/Brisbane",
          recurrence: "every_week",
          recurrence_until: 30.days.from_now.iso8601,
          status: "public",
        )

        upcoming_events.visit

        expect(upcoming_events).to have_event_count(4)
      end
    end
  end

  describe "event filtering" do
    it "loads events for the visible date range", time: Time.utc(2025, 9, 1, 12, 0) do
      create_event(
        title: "Company trip to the Prague zoo",
        start: "2025-09-07 18:30",
        end_time: "2025-09-07 21:00",
        timezone: "Europe/Prague",
        status: "public",
      )
      create_event(
        title: "October team offsite planning retreat",
        start: "2025-10-15 09:00",
        end_time: "2025-10-15 17:00",
        timezone: "Europe/Prague",
        status: "public",
      )

      visit("/upcoming-events/week/2025/9/1")

      expect(upcoming_events).to have_event("Prague zoo")
      expect(upcoming_events).to have_no_event("October team offsite")
    end

    it "filters to only attending events", time: Time.utc(2025, 6, 2, 19, 00) do
      attending =
        create_event(
          title: "Conference I am attending this week",
          start: "2025-06-11 08:05",
          status: "public",
        )
      create_event(title: "Workshop I will not attend", start: "2025-06-12 08:05")

      DiscoursePostEvent::Event.find(attending.id).create_invitees(
        [{ user_id: admin.id, status: 0 }],
      )

      upcoming_events.visit

      expect(upcoming_events).to have_event("Conference I am attending")
      expect(upcoming_events).to have_event("Workshop I will not attend")

      upcoming_events.open_mine_events

      expect(upcoming_events).to have_event("Conference I am attending")
      expect(upcoming_events).to have_no_event("Workshop I will not attend")
    end
  end

  describe "calendar navigation" do
    describe "today button" do
      it "navigates to current date", time: Time.utc(2025, 6, 2, 19, 00) do
        visit("/upcoming-events/month/2025/8/1")

        upcoming_events.today

        expect(upcoming_events).to have_current_path("/upcoming-events/month/2025/6/1")
      end

      it "respects browser timezone for day view",
         timezone: "Europe/London",
         time: Time.utc(2025, 6, 2, 19, 00) do
        visit("/upcoming-events/day/2025/8/1")

        upcoming_events.today

        expect(upcoming_events).to have_current_path("/upcoming-events/day/2025/6/2")
      end
    end

    describe "next/prev buttons" do
      it "navigates between months" do
        visit("/upcoming-events/month/2025/8/1")

        upcoming_events.next

        expect(upcoming_events).to have_content("September 2025")

        upcoming_events.prev.prev

        expect(upcoming_events).to have_content("July 2025")
      end

      it "navigates between weeks" do
        visit("/upcoming-events/week/2025/8/4")

        upcoming_events.next

        expect(upcoming_events).to have_content("Aug 11 – 17, 2025")

        upcoming_events.prev.prev

        expect(upcoming_events).to have_content("Jul 28 – Aug 3, 2025")
      end

      it "navigates between days" do
        visit("/upcoming-events/day/2025/8/1")

        upcoming_events.next

        expect(upcoming_events).to have_content("August 2, 2025")

        upcoming_events.prev.prev

        expect(upcoming_events).to have_content("July 31, 2025")
      end
    end
  end

  describe "view configuration" do
    it "uses calendar_upcoming_events_default_view setting", time: Time.utc(2025, 9, 15) do
      SiteSetting.calendar_upcoming_events_default_view = "day"

      upcoming_events.visit

      expect(upcoming_events).to have_content("September 15, 2025")
      expect(upcoming_events).to have_current_path("/upcoming-events/day/2025/9/15")
    end

    it "preserves date when switching views" do
      visit("/upcoming-events/month/2025/9/16")

      upcoming_events.open_week_view

      expect(upcoming_events).to have_content("Sep 15 – 21, 2025")
    end
  end

  describe "event duration display", time: Time.utc(2025, 6, 2, 19, 00) do
    it "reflects duration in visual height" do
      create_event(
        title: "Quick daily standup meeting",
        start: "2025-06-03 10:00",
        end_time: "2025-06-03 11:00",
      )
      create_event(
        title: "Full day architecture workshop",
        start: "2025-06-03 14:00",
        end_time: "2025-06-03 17:00",
      )

      visit("/upcoming-events/week/2025/6/2")

      expect(upcoming_events).to have_event_height("Quick daily standup meeting", 47)
      expect(upcoming_events).to have_event_height("Full day architecture workshop", 143)
    end
  end

  describe "calendar_event_display setting", time: Time.utc(2025, 6, 2, 19, 00) do
    before do
      create_event(
        title: "Weekly team planning session",
        start: "2025-06-03 10:00",
        end_time: "2025-06-03 11:00",
        recurrence: "every_week",
      )
    end

    it "renders block style when set to block" do
      SiteSetting.calendar_event_display = "block"

      visit("/upcoming-events/month/2025/9/16")

      expect(upcoming_events).to have_block_event_style
    end

    it "renders dot style when set to auto" do
      SiteSetting.calendar_event_display = "auto"

      visit("/upcoming-events/month/2025/9/16")

      expect(upcoming_events).to have_dot_event_style
    end
  end

  describe "event color mapping", time: Time.utc(2025, 6, 2, 19, 00) do
    it "colors events by tag" do
      SiteSetting.map_events_to_color = [
        { type: "tag", color: "rgb(231, 76, 60)", slug: "red-tag" },
      ].to_json

      create_post(
        user: admin,
        category: Fabricate(:category),
        topic: Fabricate(:topic, tags: [Fabricate(:tag, name: "red-tag")]),
        title: "Important quarterly review meeting",
        raw: "[event start=\"2025-06-03 10:00\" end=\"2025-06-03 11:00\"]\n[/event]",
      )

      visit("/upcoming-events/month/2025/6/16")

      expect(upcoming_events).to have_event_dot_color("rgb(231, 76, 60)")
    end

    it "colors events by category" do
      SiteSetting.map_events_to_color = [
        { type: "category", color: "rgb(231, 76, 60)", slug: "red-cat" },
      ].to_json

      create_post(
        user: admin,
        category: Fabricate(:category, slug: "red-cat"),
        title: "Annual company celebration dinner",
        raw: "[event start=\"2025-06-03 10:00\" end=\"2025-06-03 11:00\"]\n[/event]",
      )

      visit("/upcoming-events/month/2025/6/16")

      expect(upcoming_events).to have_event_dot_color("rgb(231, 76, 60)")
    end
  end
end
