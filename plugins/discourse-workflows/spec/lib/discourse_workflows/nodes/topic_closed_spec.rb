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

  describe "#matches?" do
    it "returns true when no category is configured" do
      trigger = described_class.new(topic, "closed", true)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context("category_ids" => []))).to eq(true)
    end

    it "matches topics in any of the configured categories" do
      trigger = described_class.new(topic, "closed", true)

      expect(
        trigger.matches?(
          trigger_context("category_ids" => [Fabricate(:category).id.to_s, topic.category_id.to_s]),
        ),
      ).to eq(true)
      expect(
        trigger.matches?(trigger_context("category_ids" => [Fabricate(:category).id.to_s])),
      ).to eq(false)
    end

    it "matches subcategories by default but not when excluded" do
      subcategory = Fabricate(:category, parent_category: topic.category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      trigger = described_class.new(subcategory_topic, "closed", true)

      expect(trigger.matches?(trigger_context("category_ids" => [topic.category_id.to_s]))).to eq(
        true,
      )
      expect(
        trigger.matches?(
          trigger_context(
            "category_ids" => [topic.category_id.to_s],
            "include_subcategories" => false,
          ),
        ),
      ).to eq(false)
    end

    it "supports the legacy scalar category_id parameter" do
      trigger = described_class.new(topic, "closed", true)

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(true)
    end

    it "matches subcategories by default for legacy category_id-only nodes" do
      subcategory = Fabricate(:category, parent_category: topic.category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      trigger = described_class.new(subcategory_topic, "closed", true)

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(true)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
