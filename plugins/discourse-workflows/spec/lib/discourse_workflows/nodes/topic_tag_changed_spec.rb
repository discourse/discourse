# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicTagChanged::V1 do
  fab!(:topic)

  describe "#valid?" do
    it "returns true when topic is present" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])
      expect(trigger).to be_valid
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil)
      expect(trigger).not_to be_valid
    end

    it "returns true when tags are removed" do
      trigger = described_class.new(topic, old_tag_names: %w[bug urgent], new_tag_names: ["bug"])
      expect(trigger).to be_valid
    end

    it "returns false when the tag diff is empty" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: ["bug"])
      expect(trigger).not_to be_valid
    end
  end

  describe "#output" do
    it "returns tag change data with computed diffs", :aggregate_failures do
      trigger =
        described_class.new(
          topic,
          old_tag_names: %w[bug help],
          new_tag_names: %w[bug urgent],
          user: topic.user,
        )
      output = trigger.output

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:category_id]).to eq(topic.category_id)
      expect(output[:old_tags]).to eq(%w[bug help])
      expect(output[:new_tags]).to eq(%w[bug urgent])
      expect(output[:added_tags]).to eq(%w[urgent])
      expect(output[:removed_tags]).to eq(%w[help])
      expect(output[:topic][:posters].map { |poster| poster[:user_id] }).to include(topic.user_id)
      expect(output).to match_node_output_schema(described_class)
    end

    it "handles tags added from empty" do
      trigger = described_class.new(topic, old_tag_names: [], new_tag_names: %w[bug urgent])
      output = trigger.output

      expect(output[:added_tags]).to eq(%w[bug urgent])
      expect(output[:removed_tags]).to be_empty
    end

    it "handles all tags removed" do
      trigger = described_class.new(topic, old_tag_names: %w[bug urgent], new_tag_names: [])
      output = trigger.output

      expect(output[:added_tags]).to be_empty
      expect(output[:removed_tags]).to eq(%w[bug urgent])
    end
  end

  describe "#matches?" do
    it "returns true when no category parameter is configured" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])

      expect(trigger.matches?(trigger_context({}))).to eq(true)
    end

    it "returns true when the category parameter matches the topic category" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])

      expect(trigger.matches?(trigger_context("category_ids" => [topic.category_id.to_s]))).to eq(
        true,
      )
    end

    it "matches topics in any of the configured categories" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])

      expect(
        trigger.matches?(
          trigger_context("category_ids" => [Fabricate(:category).id.to_s, topic.category_id.to_s]),
        ),
      ).to eq(true)
    end

    it "matches subcategories by default but not when excluded" do
      subcategory = Fabricate(:category, parent_category: topic.category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      trigger =
        described_class.new(subcategory_topic, old_tag_names: ["bug"], new_tag_names: %w[urgent])

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
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(
        true,
      )
    end

    it "matches subcategories by default for legacy category_id-only nodes" do
      subcategory = Fabricate(:category, parent_category: topic.category)
      subcategory_topic = Fabricate(:topic, category: subcategory)
      trigger =
        described_class.new(subcategory_topic, old_tag_names: ["bug"], new_tag_names: %w[urgent])

      expect(trigger.matches?(trigger_context("category_id" => topic.category_id.to_s))).to eq(
        true,
      )
    end

    it "returns false when the category parameter does not match the topic category" do
      other_category = Fabricate(:category)
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])

      expect(trigger.matches?(trigger_context("category_ids" => [other_category.id.to_s]))).to eq(
        false,
      )
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
