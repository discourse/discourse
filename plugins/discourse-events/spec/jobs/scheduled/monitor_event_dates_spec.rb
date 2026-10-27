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

  describe "#execute" do
    it "sends due reminders when the reminder counter is nil" do
      past_date.update!(reminder_counter: nil)
      freeze_time(past_date.starts_at - 59.minutes)

      expect_enqueued_with(
        job: :discourse_post_event_send_reminder,
        args: {
          event_id: past_event.id,
          event_date_id: past_date.id,
          reminder: "notification.1.hours",
        },
      ) { job.execute({}) }

      expect(past_date.reload.reminder_counter).to eq(1)
    end
  end

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
    it "rolls back advancement without emitting side effects and advances on the next run" do
      past_event.update!(recurrence: "every_week")
      original_date = past_date
      freeze_time 8.days.after

      allow_any_instance_of(DiscourseEvents::Events::Event).to receive(
        :set_next_recurrent_event_date,
      ).and_wrap_original do |original|
        original.call
        raise "Advancement failed"
      end

      messages = nil
      events =
        DiscourseEvent.track_events do
          messages =
            MessageBus.track_publish do
              expect { job.finish(original_date) }.to raise_error("Advancement failed")
            end
        end

      expect(events).to be_empty
      expect(messages).to be_empty
      expect(original_date.reload.finished_at).to be_nil
      expect(past_event.event_dates.pluck(:id)).to contain_exactly(original_date.id)

      allow_any_instance_of(DiscourseEvents::Events::Event).to receive(
        :set_next_recurrent_event_date,
      ).and_call_original
      events =
        DiscourseEvent.track_events(:discourse_post_event_event_ended) do
          job.finish(original_date)
          job.finish(original_date)
        end

      expect(events.size).to eq(1)
      expect(original_date.reload.finished_at).to be_present
      expect(past_event.event_dates.pending.pluck(:starts_at)).to contain_exactly(
        be_within_one_second_of(original_date.starts_at + 7.days),
      )
    end

    it "defers side effects until the enclosing transaction commits" do
      past_event.update!(recurrence: "every_week")
      original_date = past_date
      freeze_time 8.days.after

      messages = nil
      events =
        DiscourseEvent.track_events do
          messages =
            MessageBus.track_publish do
              DiscourseEvents::Events::Event.transaction(requires_new: true) do
                job.finish(original_date)
                raise ActiveRecord::Rollback
              end
            end
        end

      expect(events).to be_empty
      expect(messages).to be_empty
      expect(original_date.reload.finished_at).to be_nil
      expect(past_event.event_dates.pluck(:id)).to contain_exactly(original_date.id)
    end

    it "keeps advancement committed when a broadcast fails without repeating the ended event" do
      past_event.update!(recurrence: "every_week")
      original_date = past_date
      freeze_time 8.days.after

      allow(MessageBus).to receive(
        :publish,
      ).and_wrap_original do |original, channel, *args, **kwargs|
        raise "Event broadcast failed" if channel == "/topic/#{past_event.post.topic_id}"

        original.call(channel, *args, **kwargs)
      end

      events =
        DiscourseEvent.track_events(:discourse_post_event_event_ended) do
          expect { job.finish(original_date) }.to raise_error("Event broadcast failed")
          job.finish(original_date)
        end

      expect(events.size).to eq(1)
      expect(original_date.reload.finished_at).to be_present
      expect(past_event.event_dates.pending.pluck(:starts_at)).to contain_exactly(
        be_within_one_second_of(original_date.starts_at + 7.days),
      )
    end

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

      it "does not enqueue a post alert for automated event archival" do
        author = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        post =
          PostCreator.create!(
            author,
            title: "Quiet recurring event archive",
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Ordinary meeting notes.
              [/event]
            RAW
          )

        expect(post.reload.event).to be_present

        freeze_time(ends_at + 1.hour)
        allow(Jobs).to receive(:enqueue).and_call_original

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        expect(Jobs).not_to have_received(:enqueue).with(
          :post_alert,
          hash_including(post_id: post.id),
        )
      end

      it "does not attribute the archived edit to the system user" do
        author = Fabricate(:user, refresh_auto_groups: true)
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        post =
          PostCreator.create!(
            author,
            title: "Least-privileged event archive",
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW
          )

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        expect(post.reload.last_editor_id).to eq(author.id)
        expect(post.raw).not_to include("recurrence=")
      end

      it "does not expose restricted profile details during event rollover" do
        author = Fabricate(:user, trust_level: TrustLevel[1], refresh_auto_groups: true)
        profile_user = Fabricate(:user, trust_level: TrustLevel[1])

        profile_user.user_stat.update!(post_count: 0)
        profile_user.user_profile.update!(
          bio_raw: "private rollover biography",
          location: "private rollover location",
          website: "https://private-rollover.example.com",
        )

        SiteSetting.hide_new_user_profiles = true
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        expect(Guardian.new(author).can_see_profile?(profile_user)).to eq(false)
        expect(Discourse.system_user.guardian.can_see_profile?(profile_user)).to eq(true)

        profile_url = "#{Discourse.base_url}/u/#{profile_user.username}"
        title = "Restricted profile rollover"
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        Jobs.run_immediately!

        post = PostCreator.create!(author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Public meeting notes.
              [/event]

              #{profile_url}
            RAW

        expect(post.reload.event).to be_present
        original_topic_id = post.topic_id

        Oneboxer.invalidate(profile_url)
        allow(Oneboxer).to receive(:onebox).and_call_original

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        archived_post = post.reload
        successor_post = Topic.where(title:).where.not(id: original_topic_id).sole.first_post.reload

        expect(archived_post.last_editor_id).to eq(author.id)

        [archived_post, successor_post].each do |rendered_post|
          expect(rendered_post.raw).to include(profile_url)
          expect(rendered_post.cooked).to include(profile_url)

          expect(rendered_post.cooked).not_to include(profile_user.user_profile.bio_raw)
          expect(rendered_post.cooked).not_to include(profile_user.user_profile.location)
          expect(rendered_post.cooked).not_to include(profile_user.user_profile.website)
        end

        expect(Oneboxer).not_to have_received(:onebox).with(
          profile_url,
          hash_including(user_id: Discourse::SYSTEM_USER_ID),
        )
      end

      it "preserves attribute-like words and brackets inside quoted values" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly quoted-value planning"
        name = "Start End Recurrence recurrenceUntil Party"
        location = "West End ] Hall"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event name="#{name}" location="#{location}" start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        original_event = post.reload.event

        expect(original_event).to be_present
        expect(original_event.name).to eq(name)
        expect(original_event.location).to eq(location)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post
        successor_event = successor_post.reload.event

        expect(post.reload.raw).to include(%(name="#{name}"))
        expect(post.raw).to include(%(location="#{location}"))
        expect(post.raw).not_to match(/\srecurrence=/)

        expect(successor_post.raw).to include(%(name="#{name}"))
        expect(successor_post.raw).to include(%(location="#{location}"))
        expect(successor_event.name).to eq(name)
        expect(successor_event.location).to eq(location)
        expect(successor_event.original_starts_at).to eq_time(starts_at + 7.days)
      end

      it "preserves quoted attribute values containing event attribute names" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly year-end planning"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event name="Year End Party" location="West End Hall" start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        expect(post.reload.event).to be_present

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(post.reload.raw).to include('name="Year End Party"')
        expect(post.raw).to include('location="West End Hall"')
        expect(post.raw).not_to match(/\srecurrence=/)

        expect(successor_post.raw).to include('name="Year End Party"')
        expect(successor_post.raw).to include('location="West End Hall"')
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
      end

      it "logs a deferred rollover once rather than every monitoring run" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour

        post =
          PostCreator.create!(
            event_author,
            title: "Deferred recurring meeting",
            category: event_category.id,
            raw: <<~RAW,
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW
          )

        event_date = post.reload.event.event_dates.pending.first

        post.update_columns(hidden: true)
        expect(post.reload.hidden?).to eq(true)

        freeze_time(ends_at + 1.hour)
        allow(Rails.logger).to receive(:warn)

        2.times { job.execute({}) }

        expect(Rails.logger).to have_received(:warn).with(
          /successor rollover deferred for event date #{event_date.id}/,
        ).once

        expect(event_date.reload.finished_at).to be_nil
        expect(post.reload.event.recurrence).to eq("every_week")
        expect(Topic.where(title: "Deferred recurring meeting").count).to eq(1)
      end

      it "allows successor creation after a trusted system raw edit" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring meeting with system processing"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Original meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        event_date = post.reload.event.event_dates.pending.first

        expect(
          PostRevisor.new(post).revise!(
            Discourse.system_user,
            { raw: post.raw + "\n\nAutomatically updated media." },
            bypass_bump: true,
          ),
        ).to eq(true)

        expect(post.reload.last_editor_id).to eq(Discourse::SYSTEM_USER_ID)
        expect(post.reload.event).to be_present
        expect(
          post
            .post_revisions
            .where(user_id: Discourse::SYSTEM_USER_ID)
            .any? { |revision| revision.modifications.key?("raw") },
        ).to eq(true)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole

        expect(successor_topic.first_post.raw).to include("Automatically updated media.")
        expect(event_date.reload.finished_at).to be_present
      end

      it "allows successor creation after a moderator changes only the topic title" do
        author = Fabricate(:user, refresh_auto_groups: true)
        moderator = Fabricate(:moderator)

        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring meeting with metadata edit"
        revised_title = "Recurring meeting with updated title"

        post = PostCreator.create!(author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Original meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        event_date = post.reload.event.event_dates.pending.first

        expect(
          PostRevisor.new(post).revise!(moderator, { title: revised_title }, bypass_bump: true),
        ).to eq(true)

        expect(post.reload.last_editor_id).to eq(moderator.id)
        expect(
          post
            .post_revisions
            .where(user_id: moderator.id)
            .any? { |revision| revision.modifications.key?("raw") },
        ).to eq(false)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title: revised_title).where.not(id: original_topic_id).sole

        expect(successor_topic.first_post.user_id).to eq(author.id)
        expect(event_date.reload.finished_at).to be_present
      end

      it "does not publish a wiki editor's event under the original author's identity" do
        editor = Fabricate(:user, refresh_auto_groups: true)

        SiteSetting.edit_wiki_post_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring event added by a wiki editor"

        post =
          PostCreator.create!(
            event_author,
            title:,
            category: event_category.id,
            raw: "Original author's shared wiki notes.",
          )

        expect(
          PostRevisor.new(post).revise!(event_author, { wiki: true }, bypass_bump: true),
        ).to eq(true)

        expect(post.reload.wiki?).to eq(true)
        expect(editor.guardian.can_edit_post?(post)).to eq(true)
        expect(editor.guardian.can_create_discourse_post_event?).to eq(true)

        edited_raw = <<~RAW
          [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
          Event added by another wiki editor.
          [/event]
        RAW

        expect(PostRevisor.new(post).revise!(editor, { raw: edited_raw }, bypass_bump: true)).to eq(
          true,
        )

        post.reload
        expect(post.user_id).to eq(event_author.id)
        expect(post.last_editor_id).to eq(editor.id)

        event = post.event
        expect(event).to be_present
        expect(event.recurrence).to eq("every_week")

        event_date = event.event_dates.pending.first
        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(event_date.reload.finished_at).to be_nil
        expect(post.reload.user_id).to eq(event_author.id)
        expect(post.last_editor_id).to eq(editor.id)

        # A later, unrelated edit by the original author must not
        # implicitly authorise republication of the wiki editor's Event.
        expect(
          PostRevisor.new(post).revise!(
            event_author,
            { raw: post.raw + "\n\nOriginal author added an unrelated clarification." },
            bypass_bump: true,
          ),
        ).to eq(true)

        expect(post.reload.last_editor_id).to eq(event_author.id)
        expect(post.event.recurrence).to eq("every_week")

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(event_date.reload.finished_at).to be_nil

        expect(
          DiscourseEvents::Events::Event::CreateSuccessorTopic.call(
            params: {
              event_date_id: event_date.id,
            },
          ),
        ).to fail_a_policy(:rollover_allowed)

        expect(event_date.reload.finished_at).to be_nil
        expect(post.reload.user_id).to eq(event_author.id)
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

        expect(
          DiscourseEvents::Events::Event::CreateSuccessorTopic.call(
            params: {
              event_date_id: event.event_dates.pending.first.id,
            },
          ),
        ).to fail_a_policy(:rollover_allowed)
      end

      it "allows an event to be removed and recreated on a successor topic" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        ends_at = starts_at + 1.hour
        title = "Recurring meeting recreated after rollover"
        anchor_field = DiscourseEvents::Events::Event::RECURRENCE_ANCHOR_TOPIC_CUSTOM_FIELD

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="2027-03-29 12:00" end="2027-03-29 13:00" status="public" timezone="UTC" recurrence="every_month"]
              Original monthly meeting.
              [/event]
            RAW

        original_topic_id = post.topic_id

        freeze_time(ends_at + 1.hour)
        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_topic.reload.custom_fields[anchor_field]).to eq(starts_at.iso8601)

        expect(
          PostRevisor.new(successor_post).revise!(
            event_author,
            { raw: "The original event has been removed." },
            bypass_bump: true,
          ),
        ).to eq(true)

        expect(successor_post.reload.event).to be_nil

        replacement_raw = <<~RAW
          [event start="2027-05-03 12:00" end="2027-05-03 13:00" status="public" timezone="UTC" recurrence="every_month"]
          A new monthly series.
          [/event]
        RAW

        expect(
          PostRevisor.new(successor_post).revise!(
            event_author,
            { raw: replacement_raw },
            bypass_bump: true,
          ),
        ).to eq(true)

        replacement_event = successor_post.reload.event

        expect(replacement_event).to be_present
        expect(replacement_event.recurrence).to eq("every_month")
        expect(replacement_event.original_starts_at).to eq_time(Time.utc(2027, 5, 3, 12, 0))
        expect(replacement_event.recurrence_anchor_starts_at).to eq_time(
          Time.utc(2027, 5, 3, 12, 0),
        )
        expect(successor_topic.reload.custom_fields[anchor_field]).to be_nil
      end

      it "preserves the monthly anchor when successor creation is delayed" do
        starts_at = Time.utc(2027, 3, 29, 12, 0)
        ends_at = starts_at + 1.hour
        title = "Delayed last-Monday meeting"
        anchor_field = DiscourseEvents::Events::Event::RECURRENCE_ANCHOR_TOPIC_CUSTOM_FIELD

        freeze_time(Time.utc(2027, 3, 1, 12, 0))

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="2027-03-29 12:00" end="2027-03-29 13:00" status="public" timezone="UTC" recurrence="every_month"]
              Monthly meeting.
              [/event]
            RAW

        original_topic_id = post.topic_id
        event_date = post.reload.event.event_dates.pending.first

        expect(event_date.starts_at).to eq_time(starts_at)

        # The March occurrence was not processed until after April 26.
        freeze_time(Time.utc(2027, 5, 1, 14, 0))

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_event = successor_topic.first_post.reload.event

        expect(successor_event.original_starts_at).to eq_time(Time.utc(2027, 4, 26, 12, 0))

        expect(successor_topic.reload.custom_fields[anchor_field]).to eq(starts_at.iso8601)
        initializing_field =
          DiscourseEvents::Events::Event::RECURRENCE_ANCHOR_INITIALIZING_TOPIC_CUSTOM_FIELD
        expect(successor_topic.custom_fields[initializing_field]).to be_nil
        expect(successor_event.recurrence_anchor_starts_at).to eq_time(starts_at)

        expect(successor_event.event_dates.pending.pluck(:starts_at)).to contain_exactly(
          Time.utc(2027, 5, 31, 12, 0),
        )

        expect(event_date.reload.finished_at).to be_present
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

      it "preserves the completed occurrence and RSVP statuses when archiving an older recurring series" do
        starts_at = (Time.current.utc - 8.days).change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Existing weekly meeting"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Existing weekly meeting notes.
              [/event]
            RAW

        event = post.reload.event
        occurrence = event.event_dates.pending.first

        expect(occurrence.starts_at).to be > event.original_starts_at
        expect(occurrence.starts_at).to be > Time.current

        invitee =
          DiscourseEvents::Events::Invitee.create_attendance!(
            going_once_user.id,
            event.id,
            :interested,
          )

        original_occurrence_id = occurrence.id
        occurrence_starts_at = occurrence.starts_at
        occurrence_ends_at = occurrence.ends_at

        freeze_time(occurrence_ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        event.reload
        occurrence.reload
        invitee.reload

        expect(event.recurrence).to be_blank
        expect(event.original_starts_at).to eq_time(occurrence_starts_at)
        expect(event.original_ends_at).to eq_time(occurrence_ends_at)

        expect(event.event_dates.pluck(:id)).to contain_exactly(original_occurrence_id)
        expect(occurrence.finished_at).to eq_time(Time.current)
        expect(occurrence.starts_at).to eq_time(occurrence_starts_at)
        expect(occurrence.ends_at).to eq_time(occurrence_ends_at)

        expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:interested])
      end

      it "preserves an archived recurring event without an explicit end time" do
        starts_at = (Time.current.utc - 8.days).change(sec: 0)
        title = "Weekly meeting without an end time"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Weekly meeting notes.
              [/event]
            RAW

        event = post.reload.event
        occurrence = event.event_dates.pending.first

        expect(event.original_ends_at).to be_nil
        expect(occurrence.starts_at).to be > event.original_starts_at
        expect(occurrence.ends_at).to be_present

        invitee =
          DiscourseEvents::Events::Invitee.create_attendance!(
            going_once_user.id,
            event.id,
            :interested,
          )

        occurrence_id = occurrence.id
        occurrence_starts_at = occurrence.starts_at
        occurrence_ends_at = occurrence.ends_at

        freeze_time(occurrence_ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        event.reload
        occurrence.reload
        invitee.reload
        post.reload

        expect(event.recurrence).to be_blank
        expect(event.original_starts_at).to eq_time(occurrence_starts_at)
        expect(event.original_ends_at).to be_nil

        expect(event.event_dates.pluck(:id)).to contain_exactly(occurrence_id)
        expect(occurrence.finished_at).to eq_time(Time.current)
        expect(occurrence.starts_at).to eq_time(occurrence_starts_at)
        expect(occurrence.ends_at).to eq_time(occurrence_ends_at)

        expect(invitee.status).to eq(DiscourseEvents::Events::Invitee.statuses[:interested])

        expect(post.raw).not_to match(/\\send=/)

        successor_topic = Topic.where(title:).where.not(id: post.topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).not_to match(/\\send=/)
        expect(successor_post.reload.event.original_ends_at).to be_nil
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

      it "ignores a long malformed event tag before a valid recurring event" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly meeting after malformed event example"
        fence = "`" * 3
        malformed_tag = "[event #{"a " * 5_000}\\\" ]"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              Example of malformed Event markup:

              #{fence}
              #{malformed_tag}
              #{fence}

              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Actual recurring meeting.
              [/event]
            RAW

        original_topic_id = post.topic_id

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).to include(malformed_tag)
        expect(successor_post.event).to be_present
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
      end

      it "rolls over an event with an unmatched guillemet in an unquoted attribute" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly meeting with unquoted guillemet"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event location=«room start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        original_event = post.reload.event

        expect(original_event).to be_present
        expect(original_event.location).to eq("«room")

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).to include("location=«room")
        expect(successor_post.event.location).to eq("«room")
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
      end

      it "rolls over an event with an apostrophe in an unquoted attribute" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly meeting with unquoted apostrophe"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event name=John's start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        expect(post.reload.event).to be_present

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).to include("name=John's")
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
        expect(post.reload.event.recurrence).to be_blank
      end

      it "rolls over adjacent BBCode attributes following a quoted value" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring event with adjacent attributes"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event name='Johnny's start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}"end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        event = post.reload.event

        expect(event).to be_present
        expect(event.original_ends_at).to eq_time(ends_at)

        event_date = event.event_dates.pending.first
        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).to include("name='Johnny's")
        expect(successor_post.event).to be_present
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
        expect(event_date.reload.finished_at).to be_present
      end

      it "keeps the Event tag valid when removing a glued start attribute" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring event with adjacent bare attribute"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}"s end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        event = post.reload.event

        expect(event).to be_present

        event_date = event.event_dates.pending.first
        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(post.reload.raw).to include("[event s ")
        expect(successor_post.raw).to include("[event s ")
        expect(successor_post.event).to be_present
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
        expect(event_date.reload.finished_at).to be_present
      end

      it "ignores a code-block decoy before an event with an unquoted apostrophe" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly meeting with apostrophe and code example"
        fence = "`" * 3

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              Example of event markup:

              #{fence}
              [event start="2000-01-01 10:00" recurrence="every_week"]
              [/event]
              #{fence}

              [event name=John's start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Actual meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        expect(post.reload.event).to be_present

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole
        successor_post = successor_topic.first_post

        expect(successor_post.raw).to include(
          %[event start="2000-01-01 10:00" recurrence="every_week"],
        )
        expect(successor_post.raw).to include("name=John's")
        expect(successor_post.event.original_starts_at).to eq_time(starts_at + 7.days)
        expect(post.reload.event.recurrence).to be_blank
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

      { "deactivated" => { active: false }, "staged" => { staged: true } }.each do |status, changes|
        it "does not publish a successor for a #{status} event author" do
          author = Fabricate(:user, refresh_auto_groups: true)
          SiteSetting.discourse_post_event_allowed_on_groups =
            Group::AUTO_GROUPS[:trust_level_0].to_s

          starts_at = 7.days.after.change(sec: 0)
          ends_at = starts_at + 1.hour
          title = "Recurring event by subsequently #{status} author"

          post = PostCreator.create!(author, title:, category: event_category.id, raw: <<~RAW)
                [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
                Meeting notes.
                [/event]
              RAW

          event_date = post.reload.event.event_dates.pending.first
          original_raw = post.raw
          author.update_columns(**changes)

          expect(author.reload.active?).to eq(false) if changes.key?(:active)
          expect(author.reload.staged?).to eq(true) if changes.key?(:staged)

          freeze_time(ends_at + 1.hour)

          expect { job.execute({}) }.not_to change(Topic, :count)
          expect(event_date.reload.finished_at).to be_nil
          expect(post.reload.raw).to eq(original_raw)

          expect(
            DiscourseEvents::Events::Event::CreateSuccessorTopic.call(
              params: {
                event_date_id: event_date.id,
              },
            ),
          ).to fail_a_policy(:rollover_allowed)
        end
      end

      it "does not publish a successor for a silenced event author" do
        author = Fabricate(:user, refresh_auto_groups: true)
        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Recurring event by subsequently silenced author"

        post = PostCreator.create!(author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic = post.topic
        event_date = post.reload.event.event_dates.pending.first

        expect(original_topic.visible).to eq(true)

        expect(UserSilencer.silence(author, nil, keep_posts: true)).to eq(true)

        expect(author.reload.silenced?).to eq(true)
        expect(post.reload.hidden?).to eq(false)
        expect(original_topic.reload.visible).to eq(true)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(Topic.where(title:).where.not(id: original_topic.id)).not_to exist
        expect(author.reload.silenced?).to eq(true)
        expect(post.reload.hidden?).to eq(false)
        expect(event_date.reload.finished_at).to be_nil
        expect(post.reload.event.recurrence).to eq("every_week")

        expect(
          DiscourseEvents::Events::Event::CreateSuccessorTopic.call(
            params: {
              event_date_id: event_date.id,
            },
          ),
        ).to fail_a_policy(:rollover_allowed)

        expect(event_date.reload.finished_at).to be_nil

        UserSilencer.unsilence(author)
        expect(author.reload.silenced?).to eq(false)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole

        expect(successor_topic.first_post.user_id).to eq(author.id)
        expect(successor_topic.first_post.event).to be_present
        expect(event_date.reload.finished_at).to be_present

        expect { job.execute({}) }.not_to change(Topic, :count)
      end

      {
        "post is hidden" => :post,
        "topic is non-visible" => :topic,
      }.each do |description, restriction|
        it "defers successor creation while the source #{description}" do
          starts_at = 7.days.after.change(sec: 0)
          ends_at = starts_at + 1.hour
          title = "Moderated recurring meeting #{restriction}"

          post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
                [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
                Meeting notes.
                [/event]
              RAW

          original_topic = post.topic
          original_event = post.reload.event
          event_date = original_event.event_dates.pending.first

          case restriction
          when :post
            post.update_columns(hidden: true, hidden_at: Time.current)
          when :topic
            original_topic.update_columns(visible: false)
          end

          freeze_time(ends_at + 1.hour)

          expect { job.execute({}) }.not_to change(Topic, :count)

          expect(event_date.reload.finished_at).to be_nil
          expect(original_event.reload.recurrence).to eq("every_week")
          expect(Topic.where(title:).where.not(id: original_topic.id)).not_to exist

          case restriction
          when :post
            post.update_columns(hidden: false, hidden_at: nil)
          when :topic
            original_topic.update_columns(visible: true)
          end

          expect { job.execute({}) }.to change(Topic, :count).by(1)

          successor_topic = Topic.where(title:).where.not(id: original_topic.id).sole

          expect(successor_topic.first_post.event).to be_present
          expect(event_date.reload.finished_at).to be_present

          expect { job.execute({}) }.not_to change(Topic, :count)
        end
      end

      it "creates a successor when the original author loses event creation permission" do
        restricted_author = Fabricate(:user, refresh_auto_groups: true)

        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:trust_level_0].to_s

        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly meeting after event permission change"

        post =
          PostCreator.create!(restricted_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_topic_id = post.topic_id
        original_event = post.reload.event
        original_date = original_event.event_dates.pending.first

        expect(original_event.recurrence).to eq("every_week")

        SiteSetting.discourse_post_event_allowed_on_groups = Group::AUTO_GROUPS[:staff].to_s

        expect(Guardian.new(restricted_author).can_create_discourse_post_event?).to eq(false)

        expect(Discourse.system_user.guardian.can_create_discourse_post_event?).to eq(true)

        freeze_time(ends_at + 1.hour)

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        successor_topic = Topic.where(title:).where.not(id: original_topic_id).sole

        successor_post = successor_topic.first_post
        successor_event = successor_post.reload.event

        expect(successor_topic.user_id).to eq(restricted_author.id)
        expect(successor_post.user_id).to eq(restricted_author.id)
        expect(successor_event).to be_present
        expect(successor_event.recurrence).to eq("every_week")
        expect(successor_event.original_starts_at).to eq_time(starts_at + 7.days)

        expect(original_date.reload.finished_at).to be_present
        expect(original_event.reload.recurrence).to be_nil
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
        ).and_wrap_original do |original, request|
          if request.fetch(:params).fetch(:event_date_id) == failing_date.id
            raise StandardError, "simulated successor creation failure"
          end

          original.call(**request)
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

      it "rolls back archival when creating the successor post fails" do
        starts_at = 7.days.after.change(sec: 0)
        ends_at = starts_at + 1.hour
        title = "Weekly planning rollback"

        post = PostCreator.create!(event_author, title:, category: event_category.id, raw: <<~RAW)
              [event start="#{starts_at.utc.strftime("%Y-%m-%d %H:%M")}" end="#{ends_at.utc.strftime("%Y-%m-%d %H:%M")}" status="public" timezone="UTC" recurrence="every_week"]
              Meeting notes.
              [/event]
            RAW

        original_raw = post.raw
        event = post.reload.event
        event_date = event.event_dates.pending.first

        invitee =
          DiscourseEvents::Events::Invitee.create_attendance!(
            going_once_user.id,
            event.id,
            :interested,
          )

        freeze_time(ends_at + 1.hour)

        allow(PostCreator).to receive(:create!).and_raise(
          StandardError,
          "simulated successor post failure",
        )
        allow(Discourse).to receive(:warn_exception)

        expect { job.execute({}) }.not_to change(Topic, :count)

        expect(Discourse).to have_received(:warn_exception).with(
          an_instance_of(StandardError),
          message: "Failed to process Discourse event date #{event_date.id}",
        )

        expect(post.reload.raw).to eq(original_raw)
        expect(post.topic.reload.title).to eq(title)
        expect(event.reload.recurrence).to eq("every_week")
        expect(event.original_starts_at).to eq_time(starts_at)
        expect(event_date.reload.finished_at).to be_nil
        expect(invitee.reload.status).to eq(DiscourseEvents::Events::Invitee.statuses[:interested])

        # A subsequent monitoring run must be able to complete the rollover.
        allow(PostCreator).to receive(:create!).and_call_original

        expect { job.execute({}) }.to change(Topic, :count).by(1)

        expect(event_date.reload.finished_at).to eq_time(Time.current)
        expect(event.reload.recurrence).to be_nil

        successor_topic = Topic.where(title:).where.not(id: post.topic_id).sole
        expect(successor_topic.first_post.reload.event.recurrence).to eq("every_week")
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
