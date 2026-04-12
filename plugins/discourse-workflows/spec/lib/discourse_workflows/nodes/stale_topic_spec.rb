# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::StaleTopic::V1 do
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

      expect(output[:topic][:id]).to eq(topic.id)
      expect(output[:topic][:title]).to eq(topic.title)
      expect(output[:topic][:tags]).to eq(["stale-tag"])
      expect(output[:topic][:category_id]).to eq(topic.category_id)
    end
  end
end
