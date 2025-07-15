# frozen_string_literal: true

describe DiscourseCalendar::MonitorEventDates do
  fab!(:post_1) { Fabricate(:post) }
  fab!(:post_2) { Fabricate(:post) }
  fab!(:post_3) { Fabricate(:post) }
  fab!(:past_event) do
    Fabricate(
      :event,
      post: post_1,
      original_starts_at: 7.days.after,
      original_ends_at: 7.days.after + 1.hour,
      reminders: "15.minutes,notification.1.hours,bumpTopic.10.minutes",
    )
  end
  let(:past_date) { past_event.event_dates.first }
  fab!(:future_event) do
    Fabricate(
      :event,
      post: post_2,
      original_starts_at: 14.days.after,
      original_ends_at: 14.days.after + 1.hour,
    )
  end
  let(:future_date) { future_event.event_dates.first }

  fab!(:past_event_no_end_time) do
    Fabricate(:event, post: post_3, original_starts_at: 7.days.after)
  end
  let(:past_date_no_end_time) { past_event_no_end_time.event_dates.first }

  describe "#send_reminder" do
    it "lodge reminder jobs in correct times" do
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) do
        described_class.new.execute({})
      end

      freeze_time(7.days.after - 59.minutes)
      expect_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.1.hours",
        },
      ) { described_class.new.execute({}) }

      freeze_time(7.days.after - 14.minutes)
      expect_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.15.minutes",
        },
      ) { described_class.new.execute({}) }

      freeze_time(7.days.after - 9.minutes)
      expect_not_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.10.minutes",
        },
      ) { described_class.new.execute({}) }

      freeze_time 7.days.after
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) do
        described_class.new.execute({})
      end
    end

    it "does not lodge reminder jobs when event is deleted" do
      freeze_time(7.days.after - 59.minutes)
      past_event.update!(deleted_at: Time.now)
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) do
        described_class.new.execute({})
      end
    end
  end

  describe "#trigger_events" do
    it "sends singe event 1 hours before and when due" do
      events = DiscourseEvent.track_events { described_class.new.execute({}) }
      expect(events).not_to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).not_to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      events = DiscourseEvent.track_events { described_class.new.execute({}) }

      freeze_time(7.days.after - 59.minutes)
      events = DiscourseEvent.track_events { described_class.new.execute({}) }
      expect(events).to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).not_to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      freeze_time(7.days.after)
      events = DiscourseEvent.track_events { described_class.new.execute({}) }
      expect(events).not_to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      events = DiscourseEvent.track_events { described_class.new.execute({}) }
      expect(events).not_to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).not_to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )
    end
  end

  describe "#finish" do
    it "finishes past event" do
      described_class.new.execute({})
      expect(future_date.finished_at).to eq(nil)
      expect(past_date.finished_at).to eq(nil)

      freeze_time 8.days.after

      described_class.new.execute({})
      future_date.reload
      expect(future_date.finished_at).to eq(nil)
      expect(past_event.event_dates.pending.count).to eq(0)
      past_date.reload
      expect(past_date.finished_at).not_to eq(nil)
      past_event_no_end_time.reload
      expect(past_date_no_end_time.finished_at).not_to eq(nil)
    end

    it "creates new date for recurrent events" do
      past_event.update!(recurrence: "every_week")
      past_event_no_end_time.update!(recurrence: "every_week")

      freeze_time 8.days.after

      events = DiscourseEvent.track_events { described_class.new.execute({}) }
      expect(future_date.finished_at).to eq(nil)

      expect(past_event.event_dates.pending.count).to eq(1)
      expect(past_event.event_dates.pending.first.starts_at.to_s).to eq(
        (past_date.starts_at + 7.days).to_s,
      )

      expect(past_event_no_end_time.event_dates.pending.count).to eq(1)
      expect(past_event_no_end_time.event_dates.pending.first.starts_at.to_s).to eq(
        (past_date_no_end_time.starts_at + 7.days).to_s,
      )

      expect(events).to include(event_name: :discourse_post_event_event_ended, params: [past_event])
      expect(events).to include(
        event_name: :discourse_post_event_event_ended,
        params: [past_event_no_end_time],
      )
    end
  end

  describe "#due_reminders" do
    fab!(:invalid_event) do
      Fabricate(
        :event,
        post: Fabricate(:post),
        original_starts_at: 7.days.after,
        original_ends_at: 7.days.after + 1.hour,
        reminders: "notification.1.foo",
      )
    end

    fab!(:valid_event) do
      Fabricate(
        :event,
        post: Fabricate(:post),
        original_starts_at: 7.days.after,
        original_ends_at: 7.days.after + 1.hour,
        reminders: "notification.1.minutes",
      )
    end

    it "doesn’t list events with invalid reminders" do
      freeze_time(7.days.after - 1.minutes)
      event_dates_monitor = DiscourseCalendar::MonitorEventDates.new

      expect(event_dates_monitor.due_reminders(invalid_event.event_dates.first)).to be_blank
      expect(event_dates_monitor.due_reminders(valid_event.event_dates.first).length).to eq(1)
    end
  end
end
