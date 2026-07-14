# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicAdminButton::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
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
  end

  describe "#output" do
    it "returns topic data" do
      output = described_class.new(topic).output

      expect(output).to include(
        topic: include(id: topic.id, title: topic.title, category_id: topic.category_id),
      )
      expect(output[:topic][:tags].map { |topic_tag| topic_tag[:name] }).to eq(["test-tag"])
      expect(output[:topic][:posters].map { |poster| poster[:user_id] }).to include(topic.user_id)
    end
  end
end
