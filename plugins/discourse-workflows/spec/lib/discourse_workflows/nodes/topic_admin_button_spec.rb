# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicAdminButton::V1 do
  fab!(:topic)

  describe "#output" do
    it "returns topic data" do
      expect(described_class.new(topic).output).to include(
        topic: include(id: topic.id, title: topic.title, category_id: topic.category_id),
      )
    end
  end
end
