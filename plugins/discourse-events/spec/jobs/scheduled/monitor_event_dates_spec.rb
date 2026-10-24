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

    it "clears one-occurrence invitees when a recurring event advances" do
      going_once_user = Fabricate(:user)
      going_recurring_user = Fabricate(:user)
      invitee_klass = DiscourseEvents::Events::Invitee

      past_event.update!(recurrence: "every_week")
      invitee_klass.create_attendance!(going_once_user.id, past_event.id, :going)
      invitee_klass.create_attendance!(
        going_recurring_user.id,
        past_event.id,
        :going,
        recurring: true,
      )

      freeze_time 8.days.after
      job.execute({})

      going_once_invitee = past_event.invitees.find_by(user_id: going_once_user.id)
      going_recurring_invitee = past_event.invitees.find_by(user_id: going_recurring_user.id)

      expect(going_once_invitee).to have_attributes(status: nil, notified: false, recurring: false)
      expect(going_recurring_invitee).to have_attributes(
        status: invitee_klass.statuses[:going],
        recurring: true,
      )
    end

    it "publishes a latest update when a recurring event advances" do
      past_event.update!(recurrence: "every_week")

      freeze_time 8.days.after

      allow(TopicTrackingState).to receive(:publish_latest)

      job.execute({})

      expect(TopicTrackingState).to have_received(:publish_latest).with(past_event.post.topic)
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

      it "keeps recurring private-message events in their original topic" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        recipient = Fabricate(:user)

        post =
          PostCreator.create!(
            event_author,
            title: "Private recurring meeting",
            archetype: Archetype.private_message,
            target_usernames: recipient.username,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Confidential meeting notes.
              [/event]
            RAW
          )

        original_topic = post.topic
        original_raw = post.raw
        event = post.reload.event

        expect(event).to be_present
        expect(original_topic.archetype).to eq(Archetype.private_message)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(original_topic.reload.archetype).to eq(Archetype.private_message)
        expect(post.reload.raw).to eq(original_raw)
        expect(event.reload.recurrence).to eq("every_week")
        expect(event.event_dates.pending.first.starts_at).to be > starts_at

        expect {
          DiscourseEvents::Events::Event::CreateSuccessorTopic.call(event.event_dates.pending.first)
        }.to raise_error(Discourse::InvalidParameters)
      end

      it "preserves last-Monday recurrence after creating a successor topic" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        ends_at = starts_at + 1.hour
        title = "Last Monday planning meeting"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_month"]
              Monthly planning meeting.
              [/event]
            RAW

        original_topic_id = post.topic_id

        freeze_time(ends_at + 1.hour)
        job.execute({})

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_event = successor_topic.first_post.reload.event

        expect(successor_event.original_starts_at).to eq_time(Time.utc(2027, 4, 26, 12, 0))

        next_occurrence =
          successor_event.calculate_next_occurrence_from(
            successor_event.original_starts_at + 1.second,
          )

        expect(next_occurrence[:starts_at]).to eq(Time.utc(2027, 5, 31, 12, 0))

        expect(successor_event.recurrence_anchor_starts_at).to eq_time(starts_at)

        serialized_rule =
          DiscourseEvents::Events::BasicEventSerializer.new(successor_event, root: false).rrule

        expect(serialized_rule).to include("BYDAY=-1MO")

        freeze_time(Time.utc(2027, 4, 26, 14, 0))
        job.execute({})

        may_topic = Topic.where(title:).where.not(id: [original_topic_id, successor_topic.id]).sole

        may_event = may_topic.first_post.reload.event

        expect(may_event.original_starts_at).to eq_time(Time.utc(2027, 5, 31, 12, 0))
        expect(may_event.recurrence_anchor_starts_at).to eq_time(starts_at)
      end

      it "respects a manually changed successor recurrence date" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        ends_at = starts_at + 1.hour
        title = "Editable monthly meeting"

        original_post =
          PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="2027-03-29 12:00" end="2027-03-29 13:00" status="public" timezone="UTC" recurrence="every_month"]
              Monthly meeting.
              [/event]
            RAW

        freeze_time(ends_at + 1.hour)
        job.execute({})

        successor_topic = Topic.where(title:).where.not(id: original_post.topic_id).sole

        successor_post = successor_topic.first_post
        edited_raw = successor_post.raw.gsub("2027-04-26", "2027-05-03")

        expect(edited_raw).not_to eq(successor_post.raw)

        PostRevisor.new(successor_post).revise!(
          event_author,
          { raw: edited_raw },
          bypass_bump: true,
        )

        edited_event = successor_post.reload.event.reload
        new_start = Time.utc(2027, 5, 3, 12, 0)

        expect(edited_event.original_starts_at).to eq_time(new_start)
        expect(edited_event.recurrence_anchor_starts_at).to eq_time(new_start)

        next_occurrence = edited_event.calculate_next_occurrence_from(new_start + 1.second)

        expect(next_occurrence[:starts_at]).to eq(Time.utc(2027, 6, 7, 12, 0))
      end

      it "preserves the monthly weekday pattern when only the time is edited" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        title = "Time-adjusted monthly meeting"

        original_post =
          PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="2027-03-29 12:00" end="2027-03-29 13:00" status="public" timezone="UTC" recurrence="every_month"]
              Monthly meeting.
              [/event]
            RAW

        freeze_time(Time.utc(2027, 3, 29, 14, 0))
        job.execute({})

        successor_topic = Topic.where(title:).where.not(id: original_post.topic_id).sole
        successor_post = successor_topic.first_post

        edited_raw =
          successor_post
            .raw
            .gsub("2027-04-26 12:00", "2027-04-26 15:00")
            .gsub("2027-04-26 13:00", "2027-04-26 16:00")

        expect(edited_raw).not_to eq(successor_post.raw)

        PostRevisor.new(successor_post).revise!(
          event_author,
          { raw: edited_raw },
          bypass_bump: true,
        )

        edited_event = successor_post.reload.event.reload

        expect(edited_event.original_starts_at).to eq_time(Time.utc(2027, 4, 26, 15, 0))

        expect(edited_event.recurrence_anchor_starts_at).to eq_time(Time.utc(2027, 3, 29, 15, 0))

        next_occurrence =
          edited_event.calculate_next_occurrence_from(Time.utc(2027, 4, 26, 15, 0) + 1.second)

        expect(next_occurrence[:starts_at]).to eq(Time.utc(2027, 5, 31, 15, 0))
      end

      it "resets the anchor when the successor recurrence frequency changes" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        title = "Frequency-adjusted monthly meeting"

        original_post =
          PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="2027-03-29 12:00" end="2027-03-29 13:00" status="public" timezone="UTC" recurrence="every_month"]
              Monthly meeting.
              [/event]
            RAW

        freeze_time(Time.utc(2027, 3, 29, 14, 0))
        job.execute({})

        successor_topic = Topic.where(title:).where.not(id: original_post.topic_id).sole
        successor_post = successor_topic.first_post

        edited_raw =
          successor_post.raw.sub('recurrence="every_month"', 'recurrence="every_two_weeks"')

        expect(edited_raw).not_to eq(successor_post.raw)

        PostRevisor.new(successor_post).revise!(
          event_author,
          { raw: edited_raw },
          bypass_bump: true,
        )

        edited_event = successor_post.reload.event.reload

        expect(edited_event.recurrence).to eq("every_two_weeks")
        expect(edited_event.recurrence_anchor_starts_at).to eq_time(Time.utc(2027, 4, 26, 12, 0))

        next_occurrence =
          edited_event.calculate_next_occurrence_from(Time.utc(2027, 4, 26, 12, 0) + 1.second)

        expect(next_occurrence[:starts_at]).to eq_time(Time.utc(2027, 5, 10, 12, 0))
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

      it "continues processing later events after a successor creation failure" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        create_post =
          lambda do |title|
            PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW
          end

        failing_post = create_post.call("Failing weekly planning")
        successful_post = create_post.call("Successful weekly planning")

        failing_date = failing_post.reload.event.event_dates.pending.first
        successful_date = successful_post.reload.event.event_dates.pending.first

        expect(failing_date.id).to be < successful_date.id

        freeze_time(ends_at + 1.hour)

        allow(DiscourseEvents::Events::Event::CreateSuccessorTopic).to receive(
          :call,
        ).and_wrap_original do |original, event_date|
          if event_date.id == failing_date.id
            raise StandardError, "simulated successor creation failure"
          end

          original.call(event_date)
        end

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        expect(failing_date.reload.finished_at).to be_nil
        expect(DiscourseEvents::Events::EventDate.pending.where(id: failing_date.id)).to exist

        expect(successful_date.reload.finished_at).to be_present

        successor_topic =
          Topic
            .where(title: "Successful weekly planning")
            .where.not(id: successful_post.topic_id)
            .sole

        successor_event = successor_topic.first_post.reload.event

        expect(successor_event.original_starts_at).to eq_time(starts_at + 7.days)
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

        allow(Discourse).to receive(:warn_exception)

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(Discourse).to have_received(:warn_exception).with(
          an_instance_of(StandardError),
          message: "Failed to process Discourse event date #{event_date.id}",
        )

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
