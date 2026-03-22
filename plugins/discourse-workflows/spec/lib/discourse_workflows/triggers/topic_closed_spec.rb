# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::TopicClosed do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:topic_closed")
    end
  end

  describe ".event_name" do
    it "returns the correct event name" do
      expect(described_class.event_name).to eq(:topic_status_updated)
    end
  end

  describe "#valid?" do
    it "returns true when topic is closed" do
      trigger = described_class.new(topic, "closed", true)
      expect(trigger.valid?).to eq(true)
    end

    it "returns false when topic is reopened" do
      trigger = described_class.new(topic, "closed", false)
      expect(trigger.valid?).to eq(false)
    end

    it "returns false for non-closed status changes" do
      trigger = described_class.new(topic, "visible", true)
      expect(trigger.valid?).to eq(false)
    end
  end

  describe "#output" do
    it "returns topic_id and tags" do
      trigger = described_class.new(topic, "closed", true)
      output = trigger.output

      expect(output[:topic_id]).to eq(topic.id)
      expect(output[:tags]).to eq(["test-tag"])
    end
  end
end
