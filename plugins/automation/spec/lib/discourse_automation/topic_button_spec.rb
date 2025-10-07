# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAutomation::TopicButton do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:other_category) { Fabricate(:category) }
  fab!(:topic) { Fabricate(:topic, category:) }
  fab!(:group)

  let(:automation) do
    Fabricate(
      :automation,
      name: "Manual helper",
      script: DiscourseAutomation::Scripts::MANUAL_TOPIC_BUTTON,
      trigger: DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON,
    )
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    SiteSetting.tagging_enabled = true

    automation.upsert_field!(
      "categories",
      "categories",
      { value: [category.id] },
      target: "trigger",
    )

    automation.upsert_field!("allowed_groups", "groups", { value: [group.id] }, target: "trigger")

    automation.upsert_field!("button_label", "text", { value: "Manual helper" })
    automation.upsert_field!("button_icon", "text", { value: "sparkles" })
    automation.upsert_field!("timer_type", "choices", { value: "close" })
    automation.upsert_field!(
      "topic_timer",
      "period",
      { value: { "interval" => 1, "frequency" => "hour" } },
    )

    automation.upsert_field!("tags", "tags", { value: ["helper"] })

    GroupUser.create!(group:, user: admin)
  end

  describe ".for_topic" do
    it "returns an available button for staff" do
      buttons = described_class.for_topic(topic, admin)

      expect(buttons.size).to eq(1)

      button = buttons.first
      expect(button.available?).to eq(true)
      expect(button.to_h[:actions]).to match_array(%w[topic_timer tags])
      expect(button.to_h[:icon]).to eq("sparkles")
      expect(button.to_h[:label]).to eq("Manual helper")
      expect(button.context["topic"]).to eq(topic)
      expect(button.context["user"]).to eq(admin)
      expect(button.context["kind"]).to eq(DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON)
    end

    it "is empty when user lacks permissions" do
      expect(described_class.for_topic(topic, user)).to be_empty
    end

    it "is empty when user is not in an allowed group" do
      group.group_users.where(user: admin).destroy_all

      expect(described_class.for_topic(topic, admin)).to be_empty

      GroupUser.create!(group:, user: admin)
    end

    it "is empty when the topic category does not match" do
      other_topic = Fabricate(:topic, category: other_category)

      expect(described_class.for_topic(other_topic, admin)).to be_empty
    end

    it "is empty when no actions are configured" do
      automation.upsert_field!("timer_type", "choices", { value: "none" })
      automation.upsert_field!("tags", "tags", { value: [] })

      expect(described_class.for_topic(topic, admin)).to be_empty

      automation.upsert_field!("timer_type", "choices", { value: "close" })
      automation.upsert_field!("tags", "tags", { value: ["helper"] })
    end

    it "allows buttons without an icon" do
      automation.upsert_field!("timer_type", "choices", { value: "close" })
      automation.upsert_field!("button_icon", "text", { value: nil })

      button = described_class.for_topic(topic, admin).first

      expect(button.to_h[:icon]).to be_nil
    end

    it "returns empty when the plugin is disabled" do
      SiteSetting.discourse_automation_enabled = false

      expect(described_class.for_topic(topic, admin)).to be_empty
    end
  end
end
