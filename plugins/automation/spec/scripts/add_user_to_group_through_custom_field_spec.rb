# frozen_string_literal: true

describe "AddUserToGroupThroughCustomField" do
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

  context "with empty field value" do
    before do
      UserCustomField.create!(user_id: user_1.id, name: "user_field_#{user_field.id}", value: "")
    end

    it "does not add user to groups with empty fullnames" do
      empty_fullname_group1 = Fabricate(:group, full_name: "")
      empty_fullname_group2 = Fabricate(:group, full_name: "")

      automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

      expect(user_1.reload.in_any_groups?([empty_fullname_group1.id])).to eq(false)
      expect(user_1.reload.in_any_groups?([empty_fullname_group2.id])).to eq(false)
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

  context "with many users and groups" do
    fab!(:bangalore) { Fabricate(:group, full_name: "Bangalore, India") }
    fab!(:dublin) { Fabricate(:group, full_name: "Dublin, Ireland") }
    fab!(:iowa) { Fabricate(:group, full_name: "Iowa") }
    fab!(:missouri) { Fabricate(:group, full_name: "Missouri") }

    fab!(:user1) { Fabricate(:user, id: bangalore.id) }
    fab!(:user2) { Fabricate(:user) }
    fab!(:user3) { Fabricate(:user) }
    fab!(:user4) { Fabricate(:user) }
    fab!(:user5) { Fabricate(:user) }
    fab!(:user6) { Fabricate(:user) }

    before do
      [
        [user1, "Dublin, Ireland"],
        [user4, "Iowa"],
        [user2, "Bangalore, India"],
        [user5, ""],
        [user6, "Missouri"],
        [user3, "Bangalore, India"],
      ].each do |user, location|
        UserCustomField.create!(user: user, name: "user_field_#{user_field.id}", value: location)
      end
    end

    it "adds users to their intended groups" do
      automation.trigger!("kind" => DiscourseAutomation::Triggers::RECURRING)

      expect(bangalore.users).to match_array([user2, user3])
      expect(dublin.users).to eq([user1])
      expect(iowa.users).to eq([user4])
      expect(missouri.users).to eq([user6])
    end
  end
end
