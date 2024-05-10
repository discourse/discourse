# frozen_string_literal: true

describe "UserBadgeGranted" do
  fab!(:user)
  fab!(:tracked_badge) { Fabricate(:badge) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_BADGE_GRANTED)
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    automation.upsert_field!("badge", "choices", { value: tracked_badge.id }, target: "trigger")
  end

  context "when a badge is granted" do
    it "fires the trigger" do
      contexts = capture_contexts { BadgeGranter.grant(tracked_badge, user) }

      expect(contexts.length).to eq(1)
      expect(contexts[0]["kind"]).to eq(DiscourseAutomation::Triggers::USER_BADGE_GRANTED)
    end
  end
end
