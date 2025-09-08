# frozen_string_literal: true

describe "discourse_post_event_recurrence" do
  let(:user_1) { Fabricate(:user, admin: true) }
  let(:topic_1) { Fabricate(:topic, user: user_1) }
  let(:post_1) { Fabricate(:post, topic: topic_1) }
  let(:starts_at) { Time.zone.parse("2020-09-10 19:00") }
  let(:post_event_1) do
    Fabricate(
      :event,
      post: post_1,
      original_starts_at: starts_at,
      original_ends_at: starts_at + 1.hour,
    )
  end

  before do
    freeze_time(starts_at + 1.minute)

    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
  end

  it "delete previous notifications before creating a new one for invites" do
    going_user = Fabricate(:user)
    DiscoursePostEvent::Invitee.create_attendance!(going_user.id, post_event_1.id, :going)

    post_event_1.update!(original_starts_at: starts_at + 10.minutes)
    post_event_1.set_next_date
    post_event_1.update!(original_starts_at: starts_at - 10.minutes)
    post_event_1.set_next_date

    expect(
      going_user
        .notifications
        .where(notification_type: Notification.types[:event_invitation])
        .count,
    ).to eq(1)
  end

  describe "every_month" do
    before { post_event_1.update!(recurrence: "every_month") }

    it "sets the next month at the same weekday" do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-10-08 19:00"))
    end
  end

  describe "every_week" do
    before { post_event_1.update!(recurrence: "every_week") }

    it "sets the next week at the same weekday" do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-09-17 19:00"))
    end
  end

  describe "every_two_weeks" do
    before { post_event_1.update!(recurrence: "every_two_weeks") }

    it "sets in two weeks at the same weekday" do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-09-24 19:00"))
    end
  end

  describe "every_four_weeks" do
    before { post_event_1.update!(recurrence: "every_four_weeks") }

    it "sets in four weeks at the same weekday" do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-10-08 19:00"))
    end
  end

  describe "every_day" do
    before { post_event_1.update!(recurrence: "every_day") }

    it "sets the next day" do
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-09-11 19:00"))
    end
  end

  describe "every_weekday" do
    before do
      post_event_1.update!(
        original_starts_at: Time.zone.parse("2020-09-11 19:00"),
        original_ends_at: Time.zone.parse("2020-09-11 19:00") + 1.hour,
        recurrence: "every_weekday",
      )
    end

    it "sets the next day" do
      freeze_time(post_event_1.original_starts_at + 1.minute)
      post_event_1.set_next_date

      expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-09-14 19:00"))
    end
  end

  context "when the event has a timezone" do
    describe "every_month" do
      before { post_event_1.update!(recurrence: "every_month", timezone: "America/New_York") }

      it "sets the next month at the same weekday" do
        freeze_time(starts_at + 1.day)

        post_event_1.set_next_date

        expect(post_event_1.starts_at).to eq_time(Time.zone.parse("2020-10-08 19:00"))
      end
    end
  end
end
