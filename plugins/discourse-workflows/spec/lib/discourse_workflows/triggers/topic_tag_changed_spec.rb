# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Triggers::TopicTagChanged::V1 do
  fab!(:user)
  fab!(:topic)

  before { SiteSetting.discourse_workflows_enabled = true }

  describe ".identifier" do
    it "returns the correct identifier" do
      expect(described_class.identifier).to eq("trigger:topic_tag_changed")
    end
  end

  describe ".event_name" do
    it "returns the correct event name" do
      expect(described_class.event_name).to eq(:topic_tags_changed)
    end
  end

  describe "#valid?" do
    it "returns true when topic is present" do
      trigger = described_class.new(topic, old_tag_names: ["bug"], new_tag_names: %w[bug urgent])
      expect(trigger.valid?).to eq(true)
    end

    it "returns false when topic is nil" do
      trigger = described_class.new(nil)
      expect(trigger.valid?).to eq(false)
    end
  end

  describe "#output" do
    it "returns tag change data with computed diffs" do
      trigger =
        described_class.new(
          topic,
          old_tag_names: %w[bug help],
          new_tag_names: %w[bug urgent],
          user: user,
        )
      output = trigger.output

      expect(output[:topic_id]).to eq(topic.id)
      expect(output[:topic_title]).to eq(topic.title)
      expect(output[:category_id]).to eq(topic.category_id)
      expect(output[:old_tags]).to eq(%w[bug help])
      expect(output[:new_tags]).to eq(%w[bug urgent])
      expect(output[:added_tags]).to eq(%w[urgent])
      expect(output[:removed_tags]).to eq(%w[help])
      expect(output[:user_id]).to eq(user.id)
      expect(output[:username]).to eq(user.username)
    end

    it "handles no user" do
      trigger = described_class.new(topic, old_tag_names: ["a"], new_tag_names: ["b"])
      output = trigger.output

      expect(output[:user_id]).to be_nil
      expect(output[:username]).to be_nil
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
end
