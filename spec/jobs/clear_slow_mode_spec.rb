# frozen_string_literal: true

RSpec.describe Jobs::ClearSlowMode do
  fab!(:topic) { Fabricate(:topic, slow_mode_seconds: 3600) }
  fab!(:topic_timer) do
    Fabricate(:topic_timer, topic:, status_type: TopicTimer.types[:clear_slow_mode])
  end

  before { topic_timer.update_columns(execute_at: 1.minute.ago) }

  describe "#execute" do
    it "clears slow mode, completes the timer and triggers topic_slow_mode_cleared as the system user" do
      events =
        DiscourseEvent.track_events(:topic_slow_mode_cleared) do
          described_class.new.execute(topic_timer_id: topic_timer.id)
        end

      expect(topic.reload.slow_mode_seconds).to eq(0)
      expect(topic_timer.reload).to be_trashed
      expect(events.map { |event| event[:params] }).to eq(
        [[topic, { acting_user: Discourse.system_user }]],
      )
    end

    it "doesn't trigger an event when slow mode is already off" do
      topic.update!(slow_mode_seconds: 0)

      events =
        DiscourseEvent.track_events(:topic_slow_mode_cleared) do
          described_class.new.execute(topic_timer_id: topic_timer.id)
        end

      expect(topic_timer.reload).to be_trashed
      expect(events).to be_empty
    end
  end
end
