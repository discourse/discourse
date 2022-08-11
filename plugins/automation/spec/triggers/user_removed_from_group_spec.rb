# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "UserRemovedFromGroup" do
  fab!(:user) { Fabricate(:user) }
  fab!(:group) { Fabricate(:group) }
  fab!(:automation) {
    Fabricate(
      :automation,
      trigger: DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP
    )
  }

  before do
    SiteSetting.discourse_automation_enabled = true
    group.add(user)
  end

  context "when group is tracked" do
    before do
      automation.upsert_field!("left_group", "group", { value: group.id }, target: "trigger")
    end

    it "fires the trigger" do
      list = capture_contexts do
        group.remove(user)
      end

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggerable::USER_REMOVED_FROM_GROUP)
    end
  end

  context "when group is not tracked" do
    it "doesn’t fire the trigger" do
      list = capture_contexts do
        group.remove(user)
      end

      expect(list).to eq([])
    end
  end
end
