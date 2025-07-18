# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::DeleteExpiredEventPosts do
  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.delete_expired_event_posts_after = 1 # hour
  end

  let(:calendar_topic) { create_post(raw: "[calendar]\n[/calendar]").topic }

  it "deletes all expired event posts" do
    post_with_one_date =
      create_post(topic: calendar_topic, raw: "San Francisco [date=2013-09-13] 🌉")
    post_with_two_dates =
      create_post(
        topic: calendar_topic,
        raw: "Toronto from [date=2014-09-14] to [date=2014-09-18] 🍁",
      )
    post_with_a_date_range =
      create_post(topic: calendar_topic, raw: "Sydney [date-range from=2015-10-03 to=2015-10-07] 🐨")
    post_in_the_future =
      create_post(
        topic: calendar_topic,
        raw: "Summer ☀️ Solstice [date=#{Date.current.year + 1}-06-21]",
      )

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post_with_one_date.id)).to eq(false)
    expect(Post.exists?(post_with_two_dates.id)).to eq(false)
    expect(Post.exists?(post_with_a_date_range.id)).to eq(false)
    expect(Post.exists?(post_in_the_future.id)).to eq(true)

    expect(CalendarEvent.exists?(post: post_with_one_date)).to eq(false)
    expect(CalendarEvent.exists?(post: post_with_two_dates)).to eq(false)
    expect(CalendarEvent.exists?(post: post_with_a_date_range)).to eq(false)
    expect(CalendarEvent.exists?(post: post_in_the_future)).to eq(true)

    expect(UserHistory.find_by(post_id: post_with_one_date.id).context).to eq(
      I18n.t("discourse_calendar.event_expired"),
    )
  end

  it "does not delete holiday events" do
    matariki =
      CalendarEvent.create!(
        topic: calendar_topic,
        start_date: Date.new(2022, 6, 24),
        region: "nz",
        description: "Matariki",
      )

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(CalendarEvent.exists?(matariki.id)).to eq(true)
  end

  it "does not delete event posts outside calendar topics" do
    post = create_post(raw: "Discourse 💬 Launch 🚀 on [date=2013-02-05]")
    CalendarEvent.create!(topic: post.topic, post: post, start_date: Date.new(2013, 2, 5))

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post.id)).to eq(true)
  end

  it "does not delete recurring event posts" do
    post =
      create_post(
        topic: calendar_topic,
        raw: 'WWW - Weekly Wednesday Watercooler [date=2022-01-05 recurring="1.week"] 🐸',
      )

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post.id)).to eq(true)
  end

  it "does not delete event posts in archived topics" do
    post =
      create_post(
        topic: calendar_topic,
        raw: 'Perpignan [date-range from=2016-09-26 to=2016-09-30 timezone="Europe/Paris"] 🥖',
      )

    calendar_topic.update!(archived: true)

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post.id)).to eq(true)
  end

  it "does not delete event posts in closed topics" do
    post =
      create_post(
        topic: calendar_topic,
        raw: 'Jodhpur [date=2017-09-18 timezone="Asia/Calcutta"] 🇮🇳',
      )

    calendar_topic.update!(closed: true)

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post.id)).to eq(true)
  end

  it "deletes all replies without future event" do
    post =
      create_post(
        topic: calendar_topic,
        raw: "Singapore [date-range from=2018-09-24 to=2018-09-28] 🇸🇬",
      )
    reply_without_event =
      create_post(
        topic: calendar_topic,
        raw: "I can't wait, I'm so excited 🙌",
        reply_to_post_number: post.post_number,
      )
    reply_with_past_event =
      create_post(
        topic: calendar_topic,
        raw: "I'm afraid I will have to leave one day earlier [date=2018-09-28] 😭",
        reply_to_post_number: post.post_number,
      )
    reply_with_future_event =
      create_post(
        topic: calendar_topic,
        raw: "Hope Montréal will be as fun in [date=2019-09-23] 🇨🇦",
        reply_to_post_number: post.post_number,
      )
    indirect_reply_without_event =
      create_post(
        topic: calendar_topic,
        raw: "OMG! Have you all seen Crazy Rich Asians?",
        reply_to_post_number: reply_without_event.post_number,
      )
    indirect_reply_with_past_event =
      create_post(
        topic: calendar_topic,
        raw: "Who wants to try the Singapore Flyer on [date=2018-09-25]?",
        reply_to_post_number: reply_without_event.post_number,
      )
    indirect_reply_with_future_event =
      create_post(
        topic: calendar_topic,
        raw:
          "Oh nooooes. A huge 🦠 will hit the whole 🌎 and travel will be severely impacted [date=2019-12-31]",
        reply_to_post_number: reply_without_event.post_number,
      )

    freeze_time Time.parse("2018-10-01 00:00:00 UTC")

    DiscourseCalendar::DeleteExpiredEventPosts.new.execute(nil)

    expect(Post.exists?(post.id)).to eq(false)
    expect(Post.exists?(reply_without_event.id)).to eq(false)
    expect(Post.exists?(reply_with_past_event.id)).to eq(false)
    expect(Post.exists?(reply_with_future_event.id)).to eq(true)
    expect(Post.exists?(indirect_reply_without_event.id)).to eq(false)
    expect(Post.exists?(indirect_reply_with_past_event.id)).to eq(false)
    expect(Post.exists?(indirect_reply_with_future_event.id)).to eq(true)
  end
end
