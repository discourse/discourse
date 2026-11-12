# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicCategoryChanged::V1 do
  fab!(:category)
  fab!(:other_category, :category)
  fab!(:topic) { Fabricate(:topic, category: other_category) }
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe "#valid?" do
    it "returns true when topic and old_category are present" do
      trigger = described_class.new(topic, category)
      expect(trigger).to be_valid
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil, category)
      expect(trigger).not_to be_valid
    end

    it "returns false when old_category is nil" do
      trigger = described_class.new(topic, nil)
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns topic data with both category ids", :aggregate_failures do
      trigger = described_class.new(topic, category)
      output = trigger.output

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:old_category_id]).to eq(category.id)
      expect(output[:topic][:posters].map { |poster| poster[:user_id] }).to include(topic.user_id)
      expect(output).to match_node_output_schema(described_class)
    end
  end
end
