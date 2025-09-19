# frozen_string_literal: true

describe "Manual topic button", type: :system do
  fab!(:admin)
  fab!(:category)
  fab!(:topic) { Fabricate(:topic_with_op, category:, title: "Manual topic button test") }
  fab!(:group)

  let(:automation) do
    Fabricate(
      :automation,
      name: "Manual topic button test",
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

    automation.upsert_field!("button_label", "text", { value: "Run helper" })
    automation.upsert_field!("button_icon", "text", { value: "wand-magic" })
    automation.upsert_field!("timer_type", "choices", { value: "close" })
    automation.upsert_field!(
      "topic_timer",
      "period",
      { value: { "interval" => 1, "frequency" => "day" } },
    )

    automation.upsert_field!("tags", "tags", { value: ["manual-automation"] })

    GroupUser.create!(group:, user: admin)

    sign_in(admin)
  end

  it "exposes a topic admin menu button that runs the automation" do
    expect(DiscourseAutomation::TopicButton.for_topic(topic, admin)).not_to be_empty

    visit(topic.url)

    find(".toggle-admin-menu", match: :first).click

    expect(page).to have_css(".discourse-automation-topic-button", text: "Run helper")
    find(".discourse-automation-topic-button", text: "Run helper").click

    try_until_success do
      topic.reload
      expect(topic.public_topic_timer).to be_present
      expect(topic.tags.pluck(:name)).to include("manual-automation")
    end
  end
end
