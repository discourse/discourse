# frozen_string_literal: true

require "rails_helper"

RSpec.describe DiscourseAutomation::Scripts::ManualTopicButton do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic, category:) }

  let(:automation) do
    Fabricate(
      :automation,
      name: "Close and tag",
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

    automation.upsert_field!("button_label", "text", { value: "Close in a day" })
    automation.upsert_field!("button_icon", "text", { value: "clock" })
    automation.upsert_field!("timer_type", "choices", { value: "close" })
    automation.upsert_field!(
      "topic_timer",
      "period",
      { value: { "interval" => 1, "frequency" => "day" } },
    )

    automation.upsert_field!("tags", "tags", { value: ["manual"] })
  end

  it "schedules a close timer and adds tags" do
    freeze_time

    expect {
      automation.trigger!(
        "kind" => DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON,
        "topic" => topic,
        "user" => admin,
      )
    }.to change { topic.reload.public_topic_timer }.from(nil)

    timer = topic.reload.public_topic_timer

    expect(timer.status_type).to eq(TopicTimer.types[:close])
    expect(timer.user).to eq(admin)
    expect(timer.execute_at).to be_within(1.second).of(24.hours.from_now)

    expect(topic.tags.pluck(:name)).to include("manual")
  end

  it "raises when the acting user cannot perform the actions" do
    expect {
      automation.trigger!(
        "kind" => DiscourseAutomation::Triggers::TOPIC_MANUAL_BUTTON,
        "topic" => topic,
        "user" => user,
      )
    }.to raise_error(Discourse::InvalidAccess)

    expect(topic.reload.public_topic_timer).to be_nil
    expect(topic.tags).to be_empty
  end
end
