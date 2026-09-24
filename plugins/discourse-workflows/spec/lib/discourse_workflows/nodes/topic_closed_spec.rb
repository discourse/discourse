# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicClosed::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
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

    it "matches topics by category IDs or the legacy category parameter" do
      trigger = described_class.new(topic, "closed", true)

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(true)
      expect(
        trigger.matches?(
          trigger_context("category_ids" => [Fabricate(:category).id.to_s, topic.category_id.to_s]),
        ),
      ).to eq(true)
      expect(
        trigger.matches?(trigger_context("category_ids" => [Fabricate(:category).id.to_s])),
      ).to eq(false)
    end

    it "matches subcategories for current and legacy category filters unless excluded" do
      subcategory = Fabricate(:category, parent_category: topic.category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      trigger = described_class.new(subcategory_topic, "closed", true)

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(true)
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
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
