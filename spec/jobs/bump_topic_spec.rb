# frozen_string_literal: true

RSpec.describe Jobs::BumpTopic do
  fab!(:admin)
  fab!(:user)

  it "respects the guardian" do
    topic = Fabricate(:topic_timer, user: user).topic
    create_post(topic: topic)
    topic.category = Fabricate(:private_category, group: Fabricate(:group))
    topic.save!

    freeze_time(2.hours.from_now)

    expect do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
    end.not_to change { topic.posts.count }

    expect(topic.reload.public_topic_timer).to eq(nil)
  end

  it "cancels the timer when the system user cannot create the bump post" do
    SiteSetting.suppress_secured_categories_from_admin = true
    group = Fabricate(:group, users: [admin])
    category = Fabricate(:private_category, group: group)
    topic = Fabricate(:topic_with_op, category: category)
    timer = Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:bump])
    freeze_time(2.hours.from_now)

    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        expect do described_class.new.execute(topic_timer_id: timer.id) end.not_to change {
          topic.posts.count
        }
      end

    expect(timer.reload).to be_trashed
    expect(events.map { |event| event[:params][1] }).to eq([:cancelled])
  end

  it "rolls back a failed bump and completes its timer on retry" do
    topic = Fabricate(:topic_with_op)
    timer = Fabricate(:topic_timer, topic: topic, user: admin, status_type: TopicTimer.types[:bump])
    post_count = topic.posts.count
    freeze_time(2.hours.from_now)
    handler = proc { raise "Listener unavailable" }
    DiscourseEvent.on(:topic_timer_changed, &handler)

    expect do described_class.new.execute(topic_timer_id: timer.id) end.to raise_error(
      "Listener unavailable",
    )
    expect(topic.posts.count).to eq(post_count)

    DiscourseEvent.off(:topic_timer_changed, &handler)
    events =
      DiscourseEvent.track_events(:topic_timer_changed) do
        described_class.new.execute(topic_timer_id: timer.id)
      end

    expect(topic.posts.count).to eq(post_count + 1)
    expect(topic.reload.public_topic_timer).to eq(nil)
    expect(events.map { |event| event[:params][1] }).to eq([:completed])
  ensure
    DiscourseEvent.off(:topic_timer_changed, &handler) if handler
  end

  it "cancels the timer when its owner has been deleted" do
    timer = Fabricate(:topic_timer, user: user, status_type: TopicTimer.types[:bump])
    user.destroy!
    freeze_time(2.hours.from_now)

    expect do described_class.new.execute(topic_timer_id: timer.id) end.not_to change {
      timer.topic.posts.count
    }

    expect(timer.reload).to be_trashed
  end
end
