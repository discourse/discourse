# frozen_string_literal: true

require "rails_helper"

describe DiscourseCalendar::UpdateHolidayUsernames do
  let(:calendar_post) { create_post(raw: "[calendar]\n[/calendar]") }

  before do
    Jobs.run_immediately!
    SiteSetting.calendar_enabled = true
    SiteSetting.holiday_calendar_topic_id = calendar_post.topic_id
  end

  it "adds users on holiday to the users_on_holiday list" do
    freeze_time Time.utc(2018, 6, 5, 18, 40)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([post.user.username])

    freeze_time Time.utc(2018, 6, 7, 18, 40)
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    expect(DiscourseCalendar.users_on_holiday).to eq([])
  end

  it "adds custom field to users on holiday" do
    freeze_time Time.utc(2018, 6, 5, 10, 30)

    raw1 = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post1 = create_post(raw: raw1, topic: calendar_post.topic)

    raw2 = 'Rome [date="2018-06-05"]' # the whole day
    post2 = create_post(raw: raw2, topic: calendar_post.topic)

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post1.user.id,
      ),
    ).to be_truthy
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post2.user.id,
      ),
    ).to be_truthy

    freeze_time Time.utc(2018, 6, 6, 10, 00)
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post1.user.id,
      ),
    ).to be_truthy
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post2.user.id,
      ),
    ).to be_falsey

    freeze_time Time.utc(2018, 6, 7, 10, 00)
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post1.user.id,
      ),
    ).to be_falsey
    expect(
      UserCustomField.exists?(
        name: DiscourseCalendar::HOLIDAY_CUSTOM_FIELD,
        user_id: post2.user.id,
      ),
    ).to be_falsey
  end

  it "sets status of users on holiday" do
    SiteSetting.enable_user_status = true
    freeze_time Time.utc(2018, 6, 5, 10, 30)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    status = post.user.user_status
    expect(status).to be_present
    expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
    expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
    expect(status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))
  end

  it "doesn't set status of users on holiday if user status is disabled in site settings" do
    SiteSetting.enable_user_status = false
    freeze_time Time.utc(2018, 6, 5, 10, 30)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    expect(post.user.user_status).to be_nil
  end

  it "holiday status doesn't override status that was set by a user themselves" do
    SiteSetting.enable_user_status = true
    freeze_time Time.utc(2018, 6, 5, 10, 30)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)
    custom_status = { description: "I am working on holiday", emoji: "construction_worker_man" }
    post.user.set_status!(custom_status[:description], custom_status[:emoji])

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    status = post.user.user_status
    expect(status).to be_present
    expect(status.description).to eq(custom_status[:description])
    expect(status.emoji).to eq(custom_status[:emoji])
  end

  it "holiday status overrides status that was set by a user themselves if that status is expired" do
    SiteSetting.enable_user_status = true

    today = Time.utc(2018, 6, 5, 10, 00)
    freeze_time today

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-08" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    tomorrow = today + 1.day
    custom_status = {
      description: "I am working on holiday",
      emoji: "construction_worker_man",
      ends_at: tomorrow,
    }
    post.user.set_status!(
      custom_status[:description],
      custom_status[:emoji],
      custom_status[:ends_at],
    )

    freeze_time tomorrow + 2.day
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    status = post.user.user_status
    expect(status).to be_present
    expect(status.description).to eq(I18n.t("discourse_calendar.holiday_status.description"))
    expect(status.emoji).to eq(SiteSetting.holiday_status_emoji)
    expect(status.ends_at).to eq_time(Time.utc(2018, 6, 8, 10, 20))
  end

  it "updates status' ends_at date when user edits a holiday post" do
    SiteSetting.enable_user_status = true
    freeze_time Time.utc(2018, 6, 5, 10, 30)

    raw = 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-06-06" time="10:20:00"]'
    post = create_post(raw: raw, topic: calendar_post.topic)

    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    expect(post.user.user_status).to be_present
    expect(post.user.user_status.ends_at).to eq_time(Time.utc(2018, 6, 6, 10, 20))

    revisor = PostRevisor.new(post)
    revisor.revise!(
      post.user,
      { raw: 'Rome [date="2018-06-05" time="10:20:00"] to [date="2018-12-10" time="10:20:00"]' },
      revised_at: Time.now,
    )
    DiscourseCalendar::UpdateHolidayUsernames.new.execute(nil)

    post.user.reload
    expect(post.user.user_status).to be_present
    expect(post.user.user_status.ends_at).to eq_time(Time.utc(2018, 12, 10, 10, 20))
  end
end
