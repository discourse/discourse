# frozen_string_literal: true

require_relative "../discourse_automation_helper"

describe "AddUserTogroupThroughCustomField" do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:target_group) { Fabricate(:group, full_name: "Groupity Group") }

  fab!(:automation) do
    Fabricate(
      :automation,
      script: DiscourseAutomation::Scriptable::ADD_USER_TO_GROUP_THROUGH_CUSTOM_FIELD,
    )
  end

  before do
    automation.upsert_field!(
      "custom_field_name",
      "text",
      { value: "groupity_group" },
      target: "script",
    )
  end

  context "with no matching user custom fields" do
    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggerable::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "with one matching user" do
    before do
      UserCustomField.create!(
        user_id: user_1.id,
        name: "groupity_group",
        value: target_group.full_name,
      )
    end

    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggerable::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "when group is already present" do
    before { target_group.add(user_1) }

    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggerable::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "with user_added_to_group trigger" do
    fab!(:automation) do
      Fabricate(
        :automation,
        script: DiscourseAutomation::Scriptable::ADD_USER_TO_GROUP_THROUGH_CUSTOM_FIELD,
      )
    end

    context "with existing custom fields" do
      before do
        UserCustomField.create!(
          user_id: user_1.id,
          name: "groupity_group",
          value: target_group.full_name,
        )
      end

      it "adds the user to the group" do
        automation.trigger!(
          "kind" => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
          "user" => user_1,
        )

        expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      end
    end

    context "with non existing/matching custom fields" do
      it "does nothing" do
        expect {
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
            "user" => user_1,
          )
        }.not_to change { user_1.reload.belonging_to_group_ids.length }
      end
    end

    context "with non existing target group" do
      before { UserCustomField.create!(user_id: user_1.id, name: "groupity_group", value: "xx") }

      it "does nothing" do
        expect {
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggerable::USER_ADDED_TO_GROUP,
            "user" => user_1,
          )
        }.not_to change { user_1.reload.belonging_to_group_ids.length }
      end
    end
  end
end
