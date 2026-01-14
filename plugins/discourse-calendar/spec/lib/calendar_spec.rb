# frozen_string_literal: true

describe DiscourseCalendar::Calendar do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
  end

  let(:raw) { "[calendar]\n[/calendar]" }
  let(:calendar_post) { create_post(raw: raw) }

  it "defaults to dynamic" do
    expect(calendar_post.reload.custom_fields[DiscourseCalendar::CALENDAR_CUSTOM_FIELD]).to eq(
      "dynamic",
    )
  end

  it "adds an entry with a single date event" do
    post =
      create_post(
        topic: calendar_post.topic,
        raw: 'Rome [date="2018-06-05" timezone="Europe/Paris"]',
      )

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome")
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00+02:00")
    expect(calendar_event.end_date).to eq(nil)
    expect(calendar_event.username).to eq(post.user.username)
  end

  it "adds an entry with a single date/time event" do
    post = create_post(topic: calendar_post.topic, raw: 'Rome [date="2018-06-05" time="12:34:56"]')

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome")
    expect(calendar_event.start_date).to eq("2018-06-05T12:34:56Z")
    expect(calendar_event.end_date).to eq("2018-06-05T13:34:56Z")
    expect(calendar_event.username).to eq(post.user.username)
  end

  it "adds an entry with a range event" do
    post =
      create_post(
        topic: calendar_post.topic,
        raw:
          'Rome [date="2018-06-05" timezone="Europe/Paris"] → [date="2018-06-08" timezone="Europe/Paris"]',
      )

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.description).to eq("Rome")
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00+02:00")
    expect(calendar_event.end_date).to eq("2018-06-08T00:00:00+02:00")
    expect(calendar_event.username).to eq(post.user.username)
  end

  it "raises an error when there are more than 2 dates" do
    expect {
      create_post(
        topic: calendar_post.topic,
        raw: 'Rome [date="2018-06-05"] → [date="2018-06-08"] [date="2018-06-09"]',
      )
    }.to raise_error(StandardError, I18n.t("discourse_calendar.more_than_two_dates"))
  end

  it "raises an error when the calendar is not in first post" do
    expect { create_post(topic: calendar_post.topic, raw: raw) }.to raise_error(
      StandardError,
      I18n.t("discourse_calendar.calendar_must_be_in_first_post"),
    )
  end

  it "raises an error when there are more than 1 calendar" do
    expect { create_post(raw: "#{raw}\n#{raw}") }.to raise_error(
      StandardError,
      I18n.t("discourse_calendar.more_than_one_calendar"),
    )
  end

  describe "with all day event start and end time" do
    before do
      SiteSetting.all_day_event_start_time = "07:00"
      SiteSetting.all_day_event_end_time = "18:00"
    end

    it "adds an entry with a single date event" do
      post =
        create_post(
          topic: calendar_post.topic,
          raw: 'Rome [date="2018-06-05" timezone="Europe/Paris"]',
        )

      calendar_event = CalendarEvent.find_by(post_id: post.id)
      expect(calendar_event.description).to eq("Rome")
      expect(calendar_event.start_date).to eq("2018-06-05T07:00:00+02:00")
      expect(calendar_event.end_date).to eq("2018-06-05T18:00:00+02:00")
      expect(calendar_event.username).to eq(post.user.username)
    end

    it "adds an entry with a single date/time event" do
      post =
        create_post(topic: calendar_post.topic, raw: 'Rome [date="2018-06-05" time="12:34:56"]')

      calendar_event = CalendarEvent.find_by(post_id: post.id)
      expect(calendar_event.description).to eq("Rome")
      expect(calendar_event.start_date).to eq("2018-06-05T12:34:56Z")
      expect(calendar_event.end_date).to eq("2018-06-05T13:34:56Z")
      expect(calendar_event.username).to eq(post.user.username)
    end

    it "adds an entry with a range event" do
      post =
        create_post(
          topic: calendar_post.topic,
          raw:
            'Rome [date="2018-06-05" timezone="Europe/Paris"] → [date="2018-06-08" timezone="Europe/Paris"]',
        )

      calendar_event = CalendarEvent.find_by(post_id: post.id)
      expect(calendar_event.description).to eq("Rome")
      expect(calendar_event.start_date).to eq("2018-06-05T07:00:00+02:00")
      expect(calendar_event.end_date).to eq("2018-06-08T18:00:00+02:00")
      expect(calendar_event.username).to eq(post.user.username)
    end
  end
end
