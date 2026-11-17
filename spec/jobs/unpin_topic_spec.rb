# frozen_string_literal: true

RSpec.describe Jobs::UnpinTopic do
  fab!(:topic)

  describe "#execute" do
    it "unpins the topic and triggers topic_status_updated as the system user" do
      topic.update_pinned(true, true)

      events =
        DiscourseEvent.track_events(:topic_status_updated) do
          described_class.new.execute(topic_id: topic.id)
        end

      expect(topic.reload.pinned_at).to be_nil
      expect(events.map { |event| event[:params] }).to eq(
        [[topic, "pinned_globally", false, { acting_user: Discourse.system_user }]],
      )
    end

    it "doesn't trigger an event when the topic isn't pinned" do
      events =
        DiscourseEvent.track_events(:topic_status_updated) do
          described_class.new.execute(topic_id: topic.id)
        end

      expect(events).to be_empty
    end
  end
end
