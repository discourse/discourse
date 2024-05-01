# frozen_string_literal: true

describe "TopicRequiredWords" do
  fab!(:user)
  fab!(:topic)
  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scripts::TOPIC_REQUIRED_WORDS,
      trigger: DiscourseAutomation::Triggers::TOPIC,
    )
  end

  context "when updating trigger" do
    it "updates the custom field" do
      automation.upsert_field!("restricted_topic", "text", { value: topic.id }, target: "trigger")
      expect(topic.custom_fields["discourse_automation_ids"]).to eq([automation.id])

      new_topic = create_topic
      automation.upsert_field!(
        "restricted_topic",
        "text",
        { value: new_topic.id },
        target: "trigger",
      )
      expect(new_topic.custom_fields["discourse_automation_ids"]).to eq([automation.id])
    end
  end
end
