# frozen_string_literal: true

describe "AddUserTogroupThroughCustomField" do
  fab!(:user_1) { Fabricate(:user) }
  fab!(:user_2) { Fabricate(:user) }
  fab!(:target_group) { Fabricate(:group, full_name: "Groupity Group") }
  fab!(:user_field) do
    Fabricate(:user_field, name: "groupity_group", field_type: "text", description: "a nice field")
  end

  fab!(:automation) { Fabricate(:automation, script: "add_user_to_group_through_custom_field") }

  before do
    automation.upsert_field!(
      "custom_field_name",
      "custom_field",
      { value: user_field.id },
      target: "script",
    )
  end

  context "with no matching user custom fields" do
    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "with one matching user" do
    before do
      UserCustomField.create!(
        user_id: user_1.id,
        name: "user_field_#{user_field.id}",
        value: target_group.full_name,
      )
    end

    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(false)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "when group is already present" do
    before { target_group.add(user_1) }

    it "works" do
      expect(user_1.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.in_any_groups?([target_group.id])).to eq(false)

      automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

      expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      expect(user_2.reload.in_any_groups?([target_group.id])).to eq(false)
    end
  end

  context "with user_first_logged_in trigger" do
    fab!(:automation) { Fabricate(:automation, script: "add_user_to_group_through_custom_field") }

    context "with existing custom fields" do
      before do
        UserCustomField.create!(
          user_id: user_1.id,
          name: "user_field_#{user_field.id}",
          value: target_group.full_name,
        )
      end

      it "adds the user to the group" do
        automation.trigger!(
          "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
          "user" => user_1,
        )

        expect(user_1.reload.in_any_groups?([target_group.id])).to eq(true)
      end
    end

    context "with non existing/matching custom fields" do
      it "does nothing" do
        expect {
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
            "user" => user_1,
          )
        }.not_to change { user_1.reload.belonging_to_group_ids.length }
      end
    end

    context "with non existing target group" do
      before do
        UserCustomField.create!(
          user_id: user_1.id,
          name: "user_field_#{user_field.id}",
          value: "xx",
        )
      end

      it "does nothing" do
        expect {
          automation.trigger!(
            "kind" => DiscourseAutomation::Triggers::USER_FIRST_LOGGED_IN,
            "user" => user_1,
          )
        }.not_to change { user_1.reload.belonging_to_group_ids.length }
      end
    end
  end
end
