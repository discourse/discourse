# frozen_string_literal: true

RSpec.describe Jobs::CloseTopic do
  fab!(:admin)

  fab!(:topic) { Fabricate(:topic_timer, user: admin).topic }

  it "should be able to close a topic" do
    freeze_time(61.minutes.from_now) do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)

      expect(topic.reload.closed).to eq(true)

      expect(Post.last.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_minutes", count: 61))
    end
  end

  it "publishes to the topic message bus so the topic status reloads" do
    MessageBus.expects(:publish).at_least_once
    MessageBus.expects(:publish).with("/topic/#{topic.id}", reload_topic: true).once
    freeze_time(61.minutes.from_now) do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id)
    end
  end

  describe "when trying to close a topic that has already been closed" do
    it "should delete the topic timer" do
      freeze_time(topic.public_topic_timer.execute_at + 1.minute)

      topic.update!(closed: true)

      expect do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)
      end.to change { TopicTimer.exists?(topic_id: topic.id) }.from(true).to(false)
    end
  end

  describe "when trying to close a topic that has been deleted" do
    it "should delete the topic timer" do
      freeze_time(topic.public_topic_timer.execute_at + 1.minute)

      topic.trash!

      expect do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)
      end.to change { TopicTimer.exists?(topic_id: topic.id) }.from(true).to(false)
    end
  end

  describe "when user is no longer authorized to close topics" do
    fab!(:user)

    fab!(:topic) { Fabricate(:topic_timer, user: user).topic }

    it "should destroy the topic timer" do
      freeze_time(topic.public_topic_timer.execute_at + 1.minute)

      expect do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)
      end.to change { TopicTimer.exists?(topic_id: topic.id) }.from(true).to(false)

      expect(topic.reload.closed).to eq(false)
    end

    it "should reconfigure topic timer if category's topics are set to autoclose" do
      category = Fabricate(:category, auto_close_based_on_last_post: true, auto_close_hours: 5)

      topic = Fabricate(:topic, category: category)
      topic.public_topic_timer.update!(user: user)

      freeze_time(topic.public_topic_timer.execute_at + 1.minute)

      expect do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)
      end.to change { topic.reload.public_topic_timer.user }.from(user).to(
        Discourse.system_user,
      ).and change { topic.public_topic_timer.id }

      expect(topic.reload.closed).to eq(false)
    end
  end
end
