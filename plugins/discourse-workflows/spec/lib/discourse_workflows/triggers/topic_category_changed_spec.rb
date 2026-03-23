# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::TopicCategoryChanged::V1 do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: other_category) }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.discourse_workflows_enabled = true
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:topic_category_changed")
    end
  end

  describe ".event_name" do
    it "returns the correct event name" do
      expect(described_class.event_name).to eq(:topic_category_changed)
    end
  end

  describe "#valid?" do
    it "returns true when topic and old_category are present" do
      trigger = described_class.new(topic, category)
      expect(trigger.valid?).to eq(true)
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil, category)
      expect(trigger.valid?).to eq(false)
    end

    it "returns false when old_category is nil" do
      trigger = described_class.new(topic, nil)
      expect(trigger.valid?).to eq(false)
    end
  end

  describe "#output" do
    it "returns topic data with both category ids" do
      trigger = described_class.new(topic, category)
      output = trigger.output

      expect(output[:topic_id]).to eq(topic.id)
      expect(output[:topic_title]).to eq(topic.title)
      expect(output[:tags]).to eq(["test-tag"])
      expect(output[:category_id]).to eq(topic.category_id)
      expect(output[:old_category_id]).to eq(category.id)
      expect(output[:user_id]).to eq(topic.user_id)
      expect(output[:username]).to eq(topic.user.username)
    end
  end
end
