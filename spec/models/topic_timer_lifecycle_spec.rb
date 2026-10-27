# frozen_string_literal: true

RSpec.describe TopicTimer do
  fab!(:admin)
  fab!(:topic, :topic_with_op)
  fab!(:destination, :category)

  before { freeze_time }

  it "emits each publication schedule change once with its previous values" do
    scheduled_at = 1.hour.from_now.change(usec: 0)
    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        timer =
          topic.set_or_create_timer(
            TopicTimer.types[:publish_to_category],
            scheduled_at.iso8601,
            by_user: admin,
            category_id: destination.id,
          )

        timer.update!(execute_at: 2.hours.from_now)
        timer.save!
        topic.delete_topic_timer(timer.status_type, by_user: admin)
        timer.reload.trash!(admin)
      end

    expect(events.map { |event| event[:params][1] }).to eq(%i[created updated cancelled])
    expect(events.second[:params][2]).to include(
      "execute_at" => scheduled_at,
      "status_type" => TopicTimer.types[:publish_to_category],
      "category_id" => destination.id,
    )
  end

  it "emits completion when the publication timer publishes its topic" do
    timer =
      Fabricate(
        :topic_timer,
        topic: topic,
        user: admin,
        category: destination,
        status_type: TopicTimer.types[:publish_to_category],
      )
    freeze_time(2.hours.from_now)

    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        Jobs::PublishTopicToCategory.new.execute(topic_timer_id: timer.id)
      end

    expect(topic.reload.category_id).to eq(destination.id)
    expect(events.map { |event| event[:params][1] }).to eq([:completed])
  end

  it "emits completion when a timer closes a topic" do
    timer = Fabricate(:topic_timer, topic: topic, user: admin)
    freeze_time(2.hours.from_now)

    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        Jobs::CloseTopic.new.execute(topic_timer_id: timer.id)
      end

    expect(topic.reload).to be_closed
    expect(events.map { |event| event[:params][1] }).to eq([:completed])
  end

  it "emits cancellation when an active timer is destroyed" do
    timer = Fabricate(:topic_timer, topic: topic, user: admin)

    events = DiscourseEvent.track_events(:topic_timer_changed) { timer.destroy! }

    expect(events.map { |event| event[:params][1] }).to eq([:cancelled])
  end

  describe "acting user" do
    fab!(:moderator)

    def acting_users(&)
      DiscourseEvent
        .track_events(:topic_timer_changed, &)
        .map { |event| [event[:params][1], event[:params].last[:acting_user]] }
    end

    it "always passes the previous attributes before the acting user" do
      events =
        DiscourseEvent.track_events(:topic_timer_changed) do
          timer = topic.set_or_create_timer(TopicTimer.types[:close], 1, by_user: admin)
          timer.update!(execute_at: 2.hours.from_now)
          timer.finish!(:completed)
          Fabricate(:topic_timer, topic: Fabricate(:topic), user: admin).destroy!
        end

      expect(events.map { |event| event[:params].size }).to all(eq(4))
      expect(events.map { |event| event[:params][2].class }).to eq(
        [NilClass, Hash, NilClass, NilClass, NilClass],
      )
      expect(events.map { |event| event[:params].last.keys }).to all(eq([:acting_user]))
    end

    it "is the user who sets, reschedules or cancels the timer" do
      events =
        acting_users do
          timer = topic.set_or_create_timer(TopicTimer.types[:close], 1, by_user: admin)
          topic.set_or_create_timer(TopicTimer.types[:close], 2, by_user: moderator)
          topic.delete_topic_timer(timer.status_type, by_user: moderator)
          timer.reload.trash!(admin)
        end

      expect(events).to eq([[:created, admin], [:updated, moderator], [:cancelled, moderator]])
    end

    it "is the system user when nobody is given" do
      events =
        acting_users do
          topic.set_or_create_timer(TopicTimer.types[:close], 1)
          topic.set_or_create_timer(TopicTimer.types[:close], nil)
        end

      expect(events).to eq([[:created, Discourse.system_user], [:cancelled, Discourse.system_user]])
    end

    it "is the system user when a reply pushes back a timer based on the last post" do
      topic.set_or_create_timer(
        TopicTimer.types[:close],
        nil,
        by_user: admin,
        based_on_last_post: true,
        duration_minutes: 60,
      )

      freeze_time(10.minutes.from_now)

      events = acting_users { create_post(topic: topic) }

      expect(events).to eq([[:updated, Discourse.system_user]])
    end

    it "is the system user when a timer deleting replies reschedules itself" do
      Fabricate(:post, topic: topic)
      timer =
        topic.set_or_create_timer(
          TopicTimer.types[:delete_replies],
          nil,
          by_user: admin,
          duration_minutes: 60,
        )
      freeze_time(2.hours.from_now)

      events = acting_users { Jobs::DeleteReplies.new.execute(topic_timer_id: timer.id) }

      expect(events).to eq([[:updated, Discourse.system_user]])
    end

    it "is the timer's owner when it closes the topic" do
      timer = Fabricate(:topic_timer, topic: topic, user: admin)
      freeze_time(2.hours.from_now)

      events = acting_users { Jobs::CloseTopic.new.execute(topic_timer_id: timer.id) }

      expect(events).to eq([[:completed, admin]])
    end

    it "is the user who publishes the topic by hand, for every timer it removes" do
      Fabricate(
        :topic_timer,
        topic: topic,
        user: admin,
        category: destination,
        status_type: TopicTimer.types[:publish_to_category],
      )
      Fabricate(
        :topic_timer,
        topic: topic,
        user: admin,
        public_type: false,
        status_type: TopicTimer.types[:clear_slow_mode],
      )

      events = acting_users { TopicPublisher.new(topic, moderator, destination.id).publish! }

      expect(events).to contain_exactly([:completed, moderator], [:cancelled, moderator])
    end

    it "is the system user when it deletes the topic or the timer is destroyed" do
      delete_timer =
        Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:delete])
      other_timer = Fabricate(:topic_timer, topic: Fabricate(:topic), user: admin)
      freeze_time(2.hours.from_now)

      events =
        acting_users do
          Jobs::DeleteTopic.new.execute(topic_timer_id: delete_timer.id)
          other_timer.destroy!
        end

      expect(events).to eq(
        [[:completed, Discourse.system_user], [:cancelled, Discourse.system_user]],
      )
    end
  end
end
