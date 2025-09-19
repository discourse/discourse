# frozen_string_literal: true

describe DiscourseAutomation::TopicButtonsController do
  fab!(:admin)
  fab!(:user)
  fab!(:category)
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

    automation.upsert_field!("button_label", "text", { value: "Trigger helper" })
    automation.upsert_field!("button_icon", "text", { value: "bolt" })
    automation.upsert_field!("timer_type", "choices", { value: "close" })
    automation.upsert_field!(
      "topic_timer",
      "period",
      { value: { "interval" => 2, "frequency" => "hour" } },
    )

    automation.upsert_field!("tags", "tags", { value: ["helper"] })

    GroupUser.create!(group:, user: admin)
  end

  it "allows an authorized user to trigger the automation" do
    sign_in(admin)

    freeze_time

    expect do
      post "/automations/#{automation.id}/topic-buttons/trigger.json",
           params: {
             topic_id: topic.id,
           }
    end.to change { topic.reload.public_topic_timer }.from(nil)

    expect(response.status).to eq(200)
    expect(topic.reload.public_topic_timer.execute_at).to be_within(1.second).of(2.hours.from_now)
    expect(topic.tags.pluck(:name)).to include("helper")
  end

  it "returns forbidden when the user cannot perform the actions" do
    sign_in(user)

    post "/automations/#{automation.id}/topic-buttons/trigger.json", params: { topic_id: topic.id }

    expect(response.status).to eq(403)
  end

  it "returns forbidden when user is not in allowed groups" do
    sign_in(admin)
    group.group_users.where(user: admin).destroy_all

    post "/automations/#{automation.id}/topic-buttons/trigger.json", params: { topic_id: topic.id }

    expect(response.status).to eq(403)

    GroupUser.create!(group:, user: admin)
  end

  it "returns not found for an unknown automation" do
    sign_in(admin)

    post "/automations/0/topic-buttons/trigger.json", params: { topic_id: topic.id }

    expect(response.status).to eq(404)
  end
end
