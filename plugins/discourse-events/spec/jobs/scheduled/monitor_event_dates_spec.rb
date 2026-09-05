# frozen_string_literal: true

describe Jobs::DiscourseCalendar::MonitorEventDates do
  subject(:job) { described_class.new }

  fab!(:post_1, :post)
  fab!(:post_2, :post)
  fab!(:post_3, :post)
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
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) { job.execute({}) }

      freeze_time(7.days.after - 59.minutes)
      expect_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.1.hours",
        },
      ) { job.execute({}) }

      freeze_time(7.days.after - 14.minutes)
      expect_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.15.minutes",
        },
      ) { job.execute({}) }

      freeze_time(7.days.after - 9.minutes)
      expect_not_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          reminder: "notification.10.minutes",
        },
      ) { job.execute({}) }

      freeze_time 7.days.after
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) { job.execute({}) }
    end

    it "does not lodge reminder jobs when event is deleted" do
      freeze_time(7.days.after - 59.minutes)
      past_event.update!(deleted_at: Time.now)
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) { job.execute({}) }
    end

    it "does not enqueue reminder jobs when event is closed" do
      freeze_time(7.days.after - 59.minutes)
      past_event.update!(closed: true)
      expect_not_enqueued_with(job: :discourse_post_event_send_reminder) { job.execute({}) }
    end
  end

  describe "#trigger_events" do
    it "sends singe event 1 hours before and when due" do
      events = DiscourseEvent.track_events { job.execute({}) }
      expect(events).not_to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).not_to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      events = DiscourseEvent.track_events { job.execute({}) }

      freeze_time(7.days.after - 59.minutes)
      events = DiscourseEvent.track_events { job.execute({}) }
      expect(events).to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).not_to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      freeze_time(7.days.after)
      events = DiscourseEvent.track_events { job.execute({}) }
      expect(events).not_to include(
        event_name: :discourse_post_event_event_will_start,
        params: [past_event],
      )
      expect(events).to include(
        event_name: :discourse_post_event_event_started,
        params: [past_event],
      )

      events = DiscourseEvent.track_events { job.execute({}) }
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
      job.execute({})
      expect(future_date.finished_at).to eq(nil)
      expect(past_date.finished_at).to eq(nil)

      freeze_time 8.days.after

      job.execute({})
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

      events = DiscourseEvent.track_events { job.execute({}) }
      expect(future_date.finished_at).to eq(nil)

      expect(past_event.event_dates.pending.count).to eq(1)
      expect(past_event.event_dates.pending.first.starts_at.to_s).to eq(
        (past_date.starts_at + 7.days).to_s,
      )

      expect(past_event_no_end_time.event_dates.pending.count).to eq(1)
      expect(past_event_no_end_time.event_dates.pending.first.starts_at.to_s).to eq(
        (past_date_no_end_time.starts_at + 7.days).to_s,
      )

      expect(events).to include(
        event_name: :discourse_post_event_event_ended,
        params: [past_event, past_date],
      )
      expect(events).to include(
        event_name: :discourse_post_event_event_ended,
        params: [past_event_no_end_time, past_date_no_end_time],
      )
    end

    context "when recurring topic mode is create_next_topic" do
      fab!(:event_author) { Fabricate(:user, admin: true, refresh_auto_groups: true) }
      fab!(:event_category, :category)
      fab!(:event_tag, :tag)
      fab!(:going_once_user, :user)
      fab!(:going_recurring_user, :user)

      before do
        SiteSetting.discourse_events_enabled = true
        SiteSetting.discourse_post_event_enabled = true
        SiteSetting.discourse_post_event_recurring_topic_mode = "create_next_topic"
      end

      it "truncates the archived title while preserving the occurrence date" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title =
          ("Weekly planning meeting discussion notes agenda " * 10)[
            0,
            SiteSetting.max_topic_title_length
          ]

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic = post.topic

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload

        suffix = " — #{starts_at.utc.strftime("%Y-%m-%d")}"

        expect(original_topic.title.length).to eq(SiteSetting.max_topic_title_length)
        expect(original_topic.title).to end_with(suffix)

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole

        expect(successor_topic.title).to eq(title)
      end

      it "archives the final occurrence without creating a successor topic" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Finite weekly planning meeting"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week" recurrenceUntil="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}"]
              Final meeting notes.
              [/event]
            RAW

        original_topic = post.topic
        original_event = post.reload.event

        DiscourseEvents::Events::Invitee.create_attendance!(
          going_once_user.id,
          original_event.id,
          :going,
        )

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.not_to change(Topic, :count)

        original_topic.reload
        original_event.reload
        post.reload

        expect(original_topic.title).to eq("#{title} — #{starts_at.utc.strftime("%Y-%m-%d")}")
        expect(original_event.recurrence).to be_blank
        expect(original_event.recurrence_until).to be_nil
        expect(original_event.event_dates.pending).to be_empty

        invitee = original_event.invitees.find_by(user_id: going_once_user.id)
        expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])

        expect(post.raw).not_to include("recurrenceUntil")
        expect(post.raw).not_to include("recurrence-until")
        expect(post.raw).not_to match(/\srecurrence=/)
      end

      it "preserves all-day dates without timezone drift" do
        starts_on = 7.days.after.to_date
        title = "Weekly all-day planning meeting"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_on}" end="#{starts_on}" all-day="true" status="public" timezone="America/Los_Angeles" recurrence="every_week"]
              All-day meeting notes.
              [/event]
            RAW

        original_topic = post.topic
        original_event = post.reload.event
        original_date = original_event.event_dates.pending.first

        freeze_time(original_date.ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload
        original_event.reload

        expect(original_topic.title).to eq("#{title} — #{starts_on}")
        expect(original_event.original_starts_at).to eq_time(starts_on.to_time(:utc))
        expect(original_event.recurrence).to be_blank

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole
        successor_event = successor_topic.first_post.event

        expect(successor_event.all_day).to eq(true)
        expect(successor_event.original_starts_at.to_date).to eq(starts_on + 7.days)
        expect(successor_topic.first_post.raw).to include("start=#{starts_on + 7.days}")
      end

      it "ignores event markup in code blocks when creating a successor" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly planning with event example"
        fence = "`" * 3

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              Example Event markup:

              #{fence}
              [event start="2000-01-01 10:00" recurrence="every_week"]
              [/event]
              #{fence}

              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Actual meeting notes.
              [/event]
            RAW

        original_topic = post.topic
        original_event = post.reload.event
        original_date = original_event.event_dates.pending.first

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload
        original_event.reload
        post.reload

        expect(post.raw).to include(%[event start="2000-01-01 10:00" recurrence="every_week"])
        expect(original_event.recurrence).to be_blank

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole
        successor_post = successor_topic.first_post
        successor_event = successor_post.event

        expect(successor_post.raw).to include(
          %[event start="2000-01-01 10:00" recurrence="every_week"],
        )
        expect(successor_event.original_starts_at).to eq_time(original_date.starts_at + 7.days)
      end

      it "disambiguates archived titles that collide after truncation" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        prefix =
          ("Weekly planning meeting discussion notes agenda " * 10)[
            0,
            SiteSetting.max_topic_title_length - 1
          ]
        first_title = "#{prefix}A"
        second_title = "#{prefix}B"

        first_post =
          PostCreator.create!(
            event_author,
            title: first_title,
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              First meeting.
              [/event]
            RAW
          )

        second_post =
          PostCreator.create!(
            event_author,
            title: second_title,
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Second meeting.
              [/event]
            RAW
          )

        first_topic = first_post.topic
        second_topic = second_post.topic

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(2)

        first_topic.reload
        second_topic.reload

        expect(first_topic.title).not_to eq(second_topic.title)
        expect(first_topic.title).to end_with(starts_at.utc.strftime("%Y-%m-%d"))
        expect(second_topic.title).to include(starts_at.utc.strftime("%Y-%m-%d"))
        expect(first_topic.title.length).to be <= SiteSetting.max_topic_title_length
        expect(second_topic.title.length).to be <= SiteSetting.max_topic_title_length

        expect(Topic.where(title: first_title).where.not(id: first_topic.id)).to exist
        expect(Topic.where(title: second_title).where.not(id: second_topic.id)).to exist
      end

      it "creates a successor when the maximum topic title length is shorter than the archive suffix" do
        SiteSetting.min_topic_title_length = 1
        SiteSetting.max_topic_title_length = 5

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Meet"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic = post.topic

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload

        expect(original_topic.title.length).to be <= SiteSetting.max_topic_title_length
        expect(Topic.where(title:).where.not(id: original_topic.id)).to exist
      end

      it "avoids archive title collisions hidden from the original author" do
        original_author = Fabricate(:user, refresh_auto_groups: true)
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly planning with hidden collision"

        post =
          PostCreator.create!(original_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic = post.topic
        archive_title = "#{title} — #{starts_at.utc.strftime("%Y-%m-%d")}"

        private_group = Fabricate(:group)
        hidden_category =
          Fabricate(:category).tap do |category|
            category.set_permissions(private_group => :full)
            category.save!
          end

        Fabricate(:topic, title: archive_title, category: hidden_category, user: event_author)

        expect(original_author.guardian.can_see_category?(hidden_category)).to eq(false)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload

        expect(original_topic.title).to eq("#{archive_title} ##{original_topic.id}")
        expect(Topic.where(title:).where.not(id: original_topic.id)).to exist
      end

      it "creates a successor when the original author can no longer create topics in the category" do
        restricted_author = Fabricate(:user, refresh_auto_groups: true)
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly planning after permission change"

        post =
          PostCreator.create!(restricted_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic = post.topic

        event_category.set_permissions(everyone: :readonly, staff: :full)
        event_category.save!

        expect(restricted_author.guardian.can_create_topic_on_category?(event_category)).to eq(
          false,
        )

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole

        expect(successor_topic.user_id).to eq(restricted_author.id)
        expect(successor_topic.first_post.user_id).to eq(restricted_author.id)
        expect(successor_topic.category_id).to eq(event_category.id)
      end

      it "keeps the occurrence pending when successor creation fails" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        post =
          PostCreator.create!(
            event_author,
            title: "Weekly planning retry",
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW
          )

        event_date = post.reload.event.event_dates.pending.first

        freeze_time(ends_at + 1.hour)

        DiscourseEvents::Events::Event::CreateSuccessorTopic.stubs(:call).raises(
          StandardError,
          "successor creation failed",
        )

        expect { job.execute({}) }.to raise_error(StandardError, "successor creation failed")

        expect(event_date.reload.finished_at).to be_nil
        expect(DiscourseEvents::Events::EventDate.pending.where(id: event_date.id)).to exist
      end

      it "preserves the completed topic and creates a successor for the next occurrence" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly planning meeting"

        post =
          PostCreator.create!(
            event_author,
            title:,
            category: event_category.id,
            tags: [event_tag.name],
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes and files go here.
              [/event]
            RAW
          )

        original_topic = post.topic
        original_event = post.reload.event
        original_date = original_event.event_dates.pending.first

        DiscourseEvents::Events::Invitee.create_attendance!(
          going_once_user.id,
          original_event.id,
          :going,
        )
        DiscourseEvents::Events::Invitee.create_attendance!(
          going_recurring_user.id,
          original_event.id,
          :going,
          recurring: true,
        )

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        original_topic.reload
        original_event.reload

        expect(original_topic.id).to eq(post.topic_id)
        expect(original_topic.title).to eq(
          "#{title} — #{original_date.starts_at.utc.strftime("%Y-%m-%d")}",
        )
        expect(original_event.recurrence).to be_blank
        expect(original_event.event_dates.pending).to be_empty

        original_once = original_event.invitees.find_by(user_id: going_once_user.id)
        original_recurring = original_event.invitees.find_by(user_id: going_recurring_user.id)

        expect(original_once.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
        expect(original_once.recurring).to eq(false)
        expect(original_recurring.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
        expect(original_recurring.recurring).to eq(true)

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole
        successor_post = successor_topic.first_post
        successor_event = successor_post.event

        expect(successor_topic.user_id).to eq(event_author.id)
        expect(successor_topic.category_id).to eq(event_category.id)
        expect(successor_topic.tags.pluck(:name)).to contain_exactly(event_tag.name)
        expect(successor_post.raw).to include("Meeting notes and files go here.")

        expect(successor_event.recurrence).to eq("every_week")
        expect(successor_event.original_starts_at).to eq_time(original_date.starts_at + 7.days)
        expect(successor_event.original_ends_at).to eq_time(original_date.ends_at + 7.days)

        expect(successor_event.invitees.find_by(user_id: going_once_user.id)).to be_nil

        successor_recurring = successor_event.invitees.find_by(user_id: going_recurring_user.id)
        expect(successor_recurring.status).to eq(DiscourseEvents::Events::Invitee.statuses[:going])
        expect(successor_recurring.recurring).to eq(true)
      end
    end

    it "does not process closed events" do
      past_event.update!(recurrence: "every_week", closed: true)
      initial_event_date = past_event.event_dates.first

      freeze_time 8.days.after

      job.execute({})

      past_event.reload
      initial_event_date.reload
      # Closed events are not processed, so the event_date remains unchanged
      expect(initial_event_date.finished_at).to be_nil
      # And no new dates are created
      expect(past_event.event_dates.count).to eq(1)
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
      freeze_time(7.days.after - 1.minute)

      expect(job.due_reminders(invalid_event.event_dates.first)).to be_blank
      expect(job.due_reminders(valid_event.event_dates.first).length).to eq(1)
    end
  end
end
