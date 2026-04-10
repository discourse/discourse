# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicAdminButton::V1 do
  fab!(:topic)
  fab!(:tag) { Fabricate(:tag, name: "test-tag") }

  before do
    SiteSetting.tagging_enabled = true
    topic.tags << tag
  end

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:topic_admin_button")
    end
  end

  describe ".event_name" do
    it "returns nil" do
      expect(described_class.event_name).to be_nil
    end
  end

  describe ".configuration_schema" do
    it "includes label and icon" do
      expect(described_class.configuration_schema).to include(
        label: include(type: :string, required: true),
        icon: include(type: :icon, required: false),
      )
    end
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
      expect(described_class.new(topic).output).to include(
        topic:
          include(
            id: topic.id,
            title: topic.title,
            tags: ["test-tag"],
            category_id: topic.category_id,
            user_id: topic.user_id,
            username: topic.first_post&.user&.username,
          ),
      )
    end
  end
end
