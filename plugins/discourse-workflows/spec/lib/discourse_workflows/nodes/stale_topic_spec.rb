# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::StaleTopic::V1 do
  describe ".trigger_data_for" do
    fab!(:stale_topic) { Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago) }
    fab!(:fresh_topic) { Fabricate(:topic, created_at: 1.hour.ago, last_posted_at: 1.hour.ago) }
    fab!(:tag) { Fabricate(:tag, name: "stale-tag") }

    before do
      SiteSetting.tagging_enabled = true
      stale_topic.tags << tag
    end

    let(:trigger_node) do
      { "id" => "trigger-1", "type" => "trigger:stale_topic", "parameters" => { "hours" => 24 } }
    end

    it "returns one item per stale topic", :aggregate_failures do
      items = described_class.trigger_data_for(trigger_context)

      expect(items.size).to eq(1)
      expect(items.first[:topic][:id]).to eq(stale_topic.id)
      expect(items.first[:topic][:tags].map { |t| t[:name] }).to eq(["stale-tag"])
      expect(items.first).to match_node_output_schema(described_class)
    end

    context "with category filter" do
      fab!(:category)
      fab!(:subcategory) { Fabricate(:category, parent_category: category) }
      fab!(:other_category, :category)

      fab!(:stale_topic_in_category) do
        Fabricate(
          :topic,
          category: category,
          created_at: 48.hours.ago,
          last_posted_at: 48.hours.ago,
        )
      end

      fab!(:stale_topic_in_subcategory) do
        Fabricate(
          :topic,
          category: subcategory,
          created_at: 48.hours.ago,
          last_posted_at: 48.hours.ago,
        )
      end

      fab!(:stale_topic_in_other_category) do
        Fabricate(
          :topic,
          category: other_category,
          created_at: 48.hours.ago,
          last_posted_at: 48.hours.ago,
        )
      end

      let(:trigger_node) do
        {
          "id" => "trigger-1",
          "type" => "trigger:stale_topic",
          "parameters" => {
            "hours" => 24,
            "category_ids" => [category.id.to_s],
          },
        }
      end

      it "returns topics in the configured category and subcategories by default" do
        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(
          stale_topic_in_category.id,
          stale_topic_in_subcategory.id,
        )
      end

      it "only returns topics in the configured category when subcategories are excluded" do
        trigger_node["parameters"]["include_subcategories"] = false

        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(stale_topic_in_category.id)
      end

      it "returns topics across all configured categories and their subcategories" do
        trigger_node["parameters"]["category_ids"] = [category.id.to_s, other_category.id.to_s]

        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(
          stale_topic_in_category.id,
          stale_topic_in_subcategory.id,
          stale_topic_in_other_category.id,
        )
      end

      it "supports the legacy scalar category_id parameter" do
        trigger_node["parameters"].delete("category_ids")
        trigger_node["parameters"]["category_id"] = category.id.to_s

        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(
          stale_topic_in_category.id,
          stale_topic_in_subcategory.id,
        )
      end
    end

    context "with tag filter" do
      fab!(:other_tag) { Fabricate(:tag, name: "other-tag") }
      fab!(:stale_topic_with_other_tag) do
        Fabricate(:topic, created_at: 48.hours.ago, last_posted_at: 48.hours.ago).tap do |t|
          t.tags << other_tag
        end
      end

      let(:trigger_node) do
        {
          "id" => "trigger-1",
          "type" => "trigger:stale_topic",
          "parameters" => {
            "hours" => 24,
            "tag_names" => %w[stale-tag],
          },
        }
      end

      it "only returns topics that have at least one of the configured tags" do
        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(stale_topic.id)
      end

      it "accepts comma-separated strings" do
        trigger_node["parameters"]["tag_names"] = "stale-tag, other-tag"

        items = described_class.trigger_data_for(trigger_context)

        topic_ids = items.map { |item| item[:topic][:id] }
        expect(topic_ids).to contain_exactly(stale_topic.id, stale_topic_with_other_tag.id)
      end
    end

    def trigger_context
      DiscourseWorkflows::TriggerNodeContext.new(trigger_node)
    end
  end
end
