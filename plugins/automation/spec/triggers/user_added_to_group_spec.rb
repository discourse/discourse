# frozen_string_literal: true

describe "UserAddedToGroup" do
  fab!(:user)
  fab!(:tracked_group) { Fabricate(:group) }
  fab!(:automation) do
    Fabricate(:automation, trigger: DiscourseAutomation::Triggers::USER_ADDED_TO_GROUP)
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
      expect(list[0]["kind"]).to eq(DiscourseAutomation::Triggers::USER_ADDED_TO_GROUP)
      expect(list[0]["user"]).to eq(user)
      expect(list[0]["group"]).to eq(tracked_group)
      expect(list[0]["usernames"]).to eq([user.username])
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
