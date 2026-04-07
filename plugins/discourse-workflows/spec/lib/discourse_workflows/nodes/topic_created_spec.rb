# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCreated::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:topic_created")
    end
  end

  describe ".event_name" do
    it "returns the correct event name" do
      expect(described_class.event_name).to eq(:topic_created)
    end
  end

  describe "#valid?" do
    it "returns true when topic is present" do
      trigger = described_class.new(topic)
      expect(trigger).to be_valid
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end

    it "returns false when skip_workflows is true" do
      trigger = described_class.new(topic, { skip_workflows: true })
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns topic data with user info" do
      trigger = described_class.new(topic)
      output = trigger.output

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags]).to eq(["test-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:topic][:user_id]).to eq(topic.user_id)
      expect(output[:topic][:username]).to eq(topic.first_post&.user&.username)
    end
  end
end
