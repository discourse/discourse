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
end
