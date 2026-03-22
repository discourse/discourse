# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::StaleTopic do
  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:stale_topic")
    end
  end

  describe ".event_name" do
    it "returns nil (polling trigger)" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".configuration_schema" do
    it "defines hours parameter" do
      schema = described_class.configuration_schema
      expect(schema[:hours]).to eq({ type: :integer, required: true, default: 24, min: 1 })
    end
  end

  describe ".output_schema" do
    it "includes topic fields" do
      schema = described_class.output_schema
      expect(schema).to eq(
        topic_id: :integer,
        topic_title: :string,
        tags: :array,
        category_id: :integer,
      )
    end
  end

  describe "#output" do
    fab!(:topic)
    fab!(:tag) { Fabricate(:tag, name: "stale-tag") }

    before do
      SiteSetting.tagging_enabled = true
      topic.tags << tag
    end

    it "returns topic data" do
      trigger = described_class.new(topic)
      output = trigger.output

      expect(output[:topic_id]).to eq(topic.id)
      expect(output[:topic_title]).to eq(topic.title)
      expect(output[:tags]).to eq(["stale-tag"])
      expect(output[:category_id]).to eq(topic.category_id)
    end
  end
end
