# frozen_string_literal: true

RSpec.describe Jobs::ToggleTopicClosed do
  fab!(:admin) { Fabricate(:admin) }

  fab!(:topic) { Fabricate(:topic_timer, user: admin).topic }

  it "should be able to close a topic" do
    topic

    freeze_time(61.minutes.from_now) do
      described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: true)

      expect(topic.reload.closed).to eq(true)

      expect(Post.last.raw).to eq(I18n.t("topic_statuses.autoclosed_enabled_minutes", count: 61))
    end
  end

  describe "opening a topic" do
    it "should be work" do
      topic.update!(closed: true)

      freeze_time(61.minutes.from_now) do
        described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: false)

        expect(topic.reload.closed).to eq(false)

        expect(Post.last.raw).to eq(I18n.t("topic_statuses.autoclosed_disabled_minutes", count: 61))
      end
    end

    describe "when category has auto close configured" do
      fab!(:category) do
        Fabricate(:category, auto_close_based_on_last_post: true, auto_close_hours: 5)
      end

      fab!(:topic) { Fabricate(:topic, category: category, closed: true) }

      it "should restore the category's auto close timer" do
        Fabricate(:topic_timer, status_type: TopicTimer.types[:open], topic: topic, user: admin)

        freeze_time(61.minutes.from_now) do
          described_class.new.execute(topic_timer_id: topic.public_topic_timer.id, state: false)

          expect(topic.reload.closed).to eq(false)

          topic_timer = topic.public_topic_timer

          expect(topic_timer.status_type).to eq(TopicTimer.types[:close])
          expect(topic_timer.execute_at).to eq_time(5.hours.from_now)
        end
      end
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
    fab!(:user) { Fabricate(:user) }

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
