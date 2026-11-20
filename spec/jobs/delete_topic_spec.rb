# frozen_string_literal: true

RSpec.describe Jobs::DeleteTopic do
  fab!(:admin)

  fab!(:topic) { Fabricate(:topic_timer, user: admin).topic }

  let(:first_post) { create_post(topic: topic) }

  it "does nothing when the topic is already deleted" do
    first_post
    topic.trash!

    freeze_time 2.hours.from_now

    Topic.any_instance.expects(:trash!).never
    described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
  end

  it "rolls back a failed deletion and completes its timer on retry" do
    first_post
    timer = topic.public_topic_timer
    timer.update!(status_type: TopicTimer.types[:delete])
    freeze_time(2.hours.from_now)
    handler = proc { raise "Listener unavailable" }
    DiscourseEvent.on(:topic_timer_changed, &handler)

    expect do described_class.new.execute(topic_timer_id: timer.id) end.to raise_error(
      "Listener unavailable",
    )
    expect(topic.reload).not_to be_trashed

    DiscourseEvent.off(:topic_timer_changed, &handler)
    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        described_class.new.execute(topic_timer_id: timer.id)
      end

    expect(topic.reload).to be_trashed
    expect(first_post.reload).to be_trashed
    expect(topic.reload.public_topic_timer).to eq(nil)
    expect(events.map { |event| event[:params][1] }).to eq([:completed])
  ensure
    DiscourseEvent.off(:topic_timer_changed, &handler) if handler
  end

  it "does nothing when run too early" do
    t = Fabricate(:topic_timer, user: admin, execute_at: 5.hours.from_now).topic
    create_post(topic: t)

    freeze_time 4.hours.from_now

    described_class.new.execute(topic_timer_id: t.public_topic_timer.id)
    expect(t.reload).to_not be_trashed
  end

  describe "user isn't authorized to delete topics" do
    let(:topic) { Fabricate(:topic_timer, user: Fabricate(:user)).topic }

    it "does not delete the topic" do
      create_post(topic: topic)

      freeze_time 2.hours.from_now

      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
      expect(topic.reload).to_not be_trashed
    end
  end
end
