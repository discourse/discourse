# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "UserAddedToGroup" do
  fab!(:user) { Fabricate(:user) }
  fab!(:tracked_group) { Fabricate(:group) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP)
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    automation.upsert_field!(
      "joined_group",
      "group",
      { value: tracked_group.id },
      target: "trigger",
    )
  end

  context "when group is tracked" do
    it "fires the trigger" do
      list = capture_contexts { tracked_group.add(user) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq("user_added_to_group")
    end
  end

  context "when group is not tracked" do
    let(:untracked_group) { Fabricate(:group) }

    it "doesn’t fire the trigger" do
      list = capture_contexts { untracked_group.add(user) }

      expect(list).to eq([])
    end
  end
end
