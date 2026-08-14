# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::EventEnded::V1 do
  fab!(:event)

  let(:topic) { event.post.topic }
  let(:event_date) { event.event_dates.first }

  before do
    SiteSetting.calendar_enabled = true
    SiteSetting.discourse_post_event_enabled = true
    SiteSetting.enable_discourse_workflows = true
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end

  it "returns the correct identifier" do
    expect(described_class.identifier).to eq("trigger:event_ended")
  end

  describe "#valid?" do
    it "returns true for an event with the occurrence that ended" do
      expect(described_class.new(event, event_date)).to be_valid
    end

    it "returns false when the event is nil" do
      expect(described_class.new(nil, event_date)).not_to be_valid
    end

    it "returns false when the occurrence is missing" do
      expect(described_class.new(event)).not_to be_valid
    end

    it "returns false when events are disabled" do
      SiteSetting.discourse_post_event_enabled = false

      expect(described_class.new(event, event_date)).not_to be_valid
    end
  end

  describe "#output" do
    it "returns the event, post, topic and RSVP counts", :aggregate_failures do
      DiscoursePostEvent::Invitee.create_attendance!(Fabricate(:user).id, event.id, :going)

      output = described_class.new(event, event_date).output

      expect(output[:event]).to include(id: event.id, name: event.name)
      expect(output[:post]).to include(id: event.post.id)
      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:stats][:going]).to eq(1)
      expect(output).to match_node_output_schema(described_class)
    end

    it "reports the dates of the occurrence that ended, not the next one" do
      ended_at = 2.days.ago
      event_date.update!(starts_at: 3.days.ago, ends_at: ended_at)
      event.event_dates.create!(starts_at: 5.days.from_now, ends_at: 6.days.from_now)

      output = described_class.new(event.reload, event_date).output

      expect(output[:event][:ends_at]).to eq(ended_at.iso8601)
    end
  end

  describe "#matches?" do
    it "matches every event when no topic is configured" do
      expect(described_class.new(event, event_date).matches?(trigger_context({}))).to eq(true)
    end

    it "matches the configured topic" do
      context = trigger_context("topic_id" => topic.id.to_s)

      expect(described_class.new(event, event_date).matches?(context)).to eq(true)
    end

    it "does not match another topic" do
      context = trigger_context("topic_id" => (topic.id + 1).to_s)

      expect(described_class.new(event, event_date).matches?(context)).to eq(false)
    end
  end
end
