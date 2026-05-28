# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicClosed::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe "#valid?" do
    it "returns true when topic is closed" do
      trigger = described_class.new(topic, "closed", true)
      expect(trigger).to be_valid
    end

    it "returns false when topic is reopened" do
      trigger = described_class.new(topic, "closed", false)
      expect(trigger).not_to be_valid
    end

    it "returns false for non-closed status changes" do
      trigger = described_class.new(topic, "visible", true)
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns topic_id and tags" do
      trigger = described_class.new(topic, "closed", true)
      output = trigger.output

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
    end
  end
end
