# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Nodes::TopicStatusChanged::V1 do
  TOPIC_STATUS_EVENTS = [
    ["closed", "closed", true],
    ["reopened", "closed", false],
    ["archived", "archived", true],
    ["unarchived", "archived", false],
    ["listed", "visible", true],
    ["unlisted", "visible", false],
    ["pinned", "pinned", true],
    ["unpinned", "pinned", false],
    ["pinned_globally", "pinned_globally", true],
    ["unpinned_globally", "pinned_globally", false],
  ].freeze

  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category: category) }

  it "exposes fixed triggers while retaining the configurable generic trigger" do
    expect(described_class).not_to be_palette_visible
    expect(described_class.properties).to have_key(:statuses)
    expect(DiscourseWorkflows::Registry.find_node_type(described_class.identifier)).to eq(
      described_class,
    )

    TOPIC_STATUS_EVENTS.each do |change, status, enabled|
      node_class = DiscourseWorkflows::Registry.find_node_type("trigger:topic_#{change}")
      expect(node_class).to be_palette_visible
      expect(node_class.properties).not_to have_key(:statuses)
      expect(node_class.i18n_scope).to eq("topic_status_changed")

      trigger = node_class.new(topic, status, enabled)
      output = trigger.output
      expect(output).to match_node_output_schema(node_class)
      if change == "closed"
        expect(output.keys).to eq([:topic])
      else
        expect(output).to include(status: status, enabled: enabled, change: change)
      end

      TOPIC_STATUS_EVENTS.each do |other_change, other_status, other_enabled|
        event = node_class.new(topic, other_status, other_enabled)
        expect(event.valid?).to eq(change == other_change)
        expect(event.matches?(trigger_context("statuses" => [other_change]))).to eq(
          change == other_change,
        )
      end

      expect(trigger.matches?(trigger_context("statuses" => ["unknown"]))).to eq(true)
      expect(trigger.matches?(trigger_context("category_ids" => [category.id]))).to eq(true)
    end
  end

  describe "#valid?" do
    it "accepts supported statuses on existing topics" do
      %w[closed autoclosed archived visible pinned pinned_globally].each do |status|
        expect(described_class.new(topic, status, true)).to be_valid
      end

      expect(described_class.new(topic, "unknown", true)).not_to be_valid
      expect(described_class.new(nil, "closed", true)).not_to be_valid
    end
  end

  describe "#output" do
    it "normalizes automatic closing and reopening" do
      closed_output = described_class.new(topic, "autoclosed", true).output
      reopened_output = described_class.new(topic, "autoclosed", false).output

      expect(closed_output).to include(status: "closed", enabled: true, change: "closed")
      expect(reopened_output).to include(status: "closed", enabled: false, change: "reopened")
      expect(closed_output[:topic][:id]).to eq(topic.id)
      expect(closed_output).to match_node_output_schema(described_class)
      expect(reopened_output).to match_node_output_schema(described_class)
    end
  end

  describe "#matches?" do
    it "matches selected changes including automatic changes" do
      trigger = described_class.new(topic, "autoclosed", false)

      expect(trigger.matches?(trigger_context({}))).to eq(true)
      expect(trigger.matches?(trigger_context("statuses" => ["reopened"]))).to eq(true)
      expect(trigger.matches?(trigger_context("statuses" => ["closed"]))).to eq(false)
    end

    it "matches categories, subcategories, and tags" do
      SiteSetting.tagging_enabled = true
      tag = Fabricate(:tag)
      other_tag = Fabricate(:tag)
      topic.tags << tag
      parent_category = Fabricate(:category)
      topic.category.update!(parent_category: parent_category)
      trigger = described_class.new(topic, "archived", true)

      expect(
        trigger.matches?(
          trigger_context("category_ids" => [parent_category.id], "tag_names" => [tag.name]),
        ),
      ).to eq(true)
      expect(
        trigger.matches?(
          trigger_context("category_ids" => [parent_category.id], "include_subcategories" => false),
        ),
      ).to eq(false)
      expect(trigger.matches?(trigger_context("tag_names" => [other_tag.name]))).to eq(false)
    end
  end

  def trigger_context(parameters)
    DiscourseWorkflows::TriggerNodeContext.new({ "parameters" => parameters })
  end
end
