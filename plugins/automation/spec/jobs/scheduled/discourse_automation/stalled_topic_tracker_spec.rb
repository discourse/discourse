# frozen_string_literal: true

describe Jobs::DiscourseAutomation::StalledTopicTracker do
  before { SiteSetting.discourse_automation_enabled = true }

  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::STALLED_TOPIC)
  end

  describe "find stalled topics" do
    fab!(:user_1) { Fabricate(:user) }
    fab!(:topic_1) { Fabricate(:topic, user: user_1, created_at: 1.month.ago) }

    before do
      automation.upsert_field!("stalled_after", "choices", { value: "PT1H" }, target: "trigger")
    end

    it "triggers the associated automation" do
      create_post(topic: topic_1, user: user_1, created_at: 1.month.ago)
      create_post(topic: topic_1, user: user_1, created_at: 1.month.ago)

      list = capture_contexts { Jobs::DiscourseAutomation::StalledTopicTracker.new.execute }

      expect(list.length).to eq(1)

      expect(list.first["kind"]).to eq(DiscourseAutomation::Triggers::STALLED_TOPIC)
      expect(list.first["topic"]["id"]).to eq(topic_1.id)
    end
  end
end
