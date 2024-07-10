# frozen_string_literal: true

describe "UserRemovedFromGroup" do
  fab!(:user)
  fab!(:group)
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_REMOVED_FROM_GROUP)
  end

  before do
    SiteSetting.discourse_automation_enabled = true
    group.add(user)
  end

  context "when group is tracked" do
    before do
      automation.upsert_field!("left_group", "group", { value: group.id }, target: "trigger")
    end

    it "fires the trigger" do
      list = capture_contexts { group.remove(user) }

      expect(list.length).to eq(1)
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::USER_REMOVED_FROM_GROUP)
      expect(list[0]["user"]).to eq(user)
      expect(list[0]["group"]).to eq(group)
      expect(list[0]["usernames"]).to eq([user.username])
    end
  end

  context "when group is not tracked" do
    it "doesn’t fire the trigger" do
      list = capture_contexts { group.remove(user) }

      expect(list).to eq([])
    end
  end
end
