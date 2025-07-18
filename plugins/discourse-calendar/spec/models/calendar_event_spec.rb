# frozen_string_literal: true

require "rails_helper"

describe CalendarEvent do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.all_day_event_start_time = ""
    SiteSetting.all_day_event_end_time = ""
  end

  it "creates the event" do
    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.topic_id).to eq(calendar_post.topic_id)
    expect(calendar_event.description).to eq("Rome")
    expect(calendar_event.start_date).to eq("2018-06-05T10:20:00Z")
    expect(calendar_event.end_date).to eq("2018-06-05T11:20:00Z")
    expect(calendar_event.username).to eq(post.user.username_lower)
  end

  it "removes the event if post does not contain dates anymore" do
    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    expect(CalendarEvent.find_by(post_id: post.id)).to be_present

    post.update(raw: "Not sure about the dates anymore")
    CookedPostProcessor.new(post).post_process

    expect(CalendarEvent.find_by(post_id: post.id)).not_to be_present
  end

  it "works with no time date" do
    raw = %{Rome [date="2018-06-05"] [date="2018-06-11"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00Z")
    expect(calendar_event.end_date).to eq("2018-06-11T00:00:00Z")
  end

  it "works with timezone" do
    raw =
      %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    calendar_event = CalendarEvent.find_by(post_id: post.id)
    expect(calendar_event.start_date).to eq("2018-06-05T00:00:00+02:00")
    expect(calendar_event.end_date).to eq("2018-06-11T13:45:33-07:00")
  end

  it "validates a post with more than two dates if not a calendar" do
    calendar_post = create_post(raw: "This is a tets of a topic")

    raw =
      %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"] [date="2018-06-05" timezone="Europe/Paris"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    expect(post).to be_valid
  end

  it "does not work if topic was deleted" do
    raw = %{Rome [date="2018-06-05" time="10:20:00"]}
    post = create_post(raw: raw, topic: calendar_post.topic)

    PostDestroyer.new(Discourse.system_user, post).destroy
    PostDestroyer.new(Discourse.system_user, calendar_post).destroy
    PostDestroyer.new(Discourse.system_user, post.reload).recover

    expect(post.deleted_at).to eq(nil)
  end

  it "recreates calendar event for all posts" do
    post = create_post(raw: 'Rome [date="2018-06-05" time="10:20:00"]', topic: calendar_post.topic)
    expect(CalendarEvent.count).to eq(1)

    PostDestroyer.new(Discourse.system_user, calendar_post.reload).destroy
    expect(CalendarEvent.count).to eq(0)

    PostDestroyer.new(Discourse.system_user, calendar_post.reload).recover
    expect(CalendarEvent.count).to eq(1)
  end

  describe "all day event site settings" do
    before do
      SiteSetting.all_day_event_start_time = "06:30"
      SiteSetting.all_day_event_end_time = "18:00"
    end

    it "works with no time date" do
      raw = %{Rome [date="2018-06-05"] [date="2018-06-11"]}
      post = create_post(raw: raw, topic: calendar_post.topic)

      calendar_event = CalendarEvent.find_by(post_id: post.id)
      expect(calendar_event.start_date).to eq("2018-06-05T06:30:00Z")
      expect(calendar_event.end_date).to eq("2018-06-11T18:00:00Z")
    end

    it "works with timezone" do
      raw =
        %{Rome [date="2018-06-05" timezone="Europe/Paris"] [date="2018-06-11" time="13:45:33" timezone="America/Los_Angeles"]}
      post = create_post(raw: raw, topic: calendar_post.topic)

      event = CalendarEvent.find_by(post_id: post.id)
      expect(event.start_date).to eq("2018-06-05T06:30:00+02:00")
      expect(event.end_date).to eq("2018-06-11T13:45:33-07:00")
    end
  end

  describe "static calendars" do
    let(:calendar_post) { create_post(raw: '[calendar type="static"]\n[/calendar]') }

    it "includes calendar details" do
      calendar_post = create_post(raw: "[calendar]\n[/calendar]")

      post =
        create_post(topic: calendar_post.topic, raw: 'Rome [date="2018-06-05" time="10:20:00"]')
      calendar_post.reload

      json = PostSerializer.new(calendar_post, scope: Guardian.new).as_json

      expect(json[:post][:calendar_details].size).to eq(1)
    end

    it "includes group timezones detail" do
      Fabricate(:admin, refresh_auto_groups: true)

      timezones_post =
        create_post(
          raw:
            "[timezones group=\"admins\"]\n[/timezones]\n\n[timezones group=\"trust_level_0\"]\n[/timezones]",
        )
      timezones_post.reload

      json = PostSerializer.new(timezones_post, scope: Guardian.new).as_json
      group_timezones = json[:post][:group_timezones]

      expect(group_timezones["admins"].count).to eq(1)
      expect(group_timezones["trust_level_0"].count).to eq(2)
    end
  end

  describe "#destroy" do
    it "removes event when a post is deleted" do
      post = create_post(raw: %{Some Event [date="2019-09-10"]}, topic: calendar_post.topic)

      expect(CalendarEvent.find_by(post_id: post.id)).to be_present

      PostDestroyer.new(Discourse.system_user, post).destroy

      expect(CalendarEvent.find_by(post_id: post.id)).to_not be_present
    end

    it "works for events belonging to deleted users" do
      SiteSetting.enable_user_status = true

      topic = Fabricate(:topic)
      user = Fabricate(:user)

      # Holiday events are not associated with a user post
      event =
        CalendarEvent.create!(
          topic_id: topic.id,
          user_id: user.id,
          start_date: Time.zone.now - 1.day,
          end_date: Time.zone.now + 1.day,
        )

      UserDestroyer.new(Discourse.system_user).destroy(user)

      expect { event.destroy! }.not_to raise_error
      expect { event.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
