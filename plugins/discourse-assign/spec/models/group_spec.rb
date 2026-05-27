# frozen_string_literal: true

RSpec.describe Group do
  let(:group) { Fabricate(:group) }

  before { SiteSetting.assign_enabled = true }

  describe "Tracking changes that could affect the allow assign on groups site setting" do
    let(:removed_group_setting) { "3|4" }
    let(:group_attribute) { group.id }

    it "removes the group from the setting when the group gets destroyed" do
      SiteSetting.assign_allowed_on_groups = "#{group_attribute}|#{removed_group_setting}"

      group.destroy!

      expect(SiteSetting.assign_allowed_on_groups).to eq removed_group_setting
    end

    it "removes the group from the setting when this is the last one on the list" do
      SiteSetting.assign_allowed_on_groups = "#{removed_group_setting}|#{group_attribute}"

      group.destroy!

      expect(SiteSetting.assign_allowed_on_groups).to eq removed_group_setting
    end

    it "removes the group from the list when it is on the middle of the list" do
      allowed_groups = "3|#{group_attribute}|4"
      SiteSetting.assign_allowed_on_groups = allowed_groups

      group.destroy!

      expect(SiteSetting.assign_allowed_on_groups).to eq removed_group_setting
    end
  end

  describe "#can_show_assigned_tab?" do
    it "returns false when assignable_level is nobody" do
      group.update!(assignable_level: Group::ALIAS_LEVELS[:nobody])
      expect(group.can_show_assigned_tab?).to eq(false)
    end

    it "returns true when assignable_level is only_admins" do
      group.update!(assignable_level: Group::ALIAS_LEVELS[:only_admins])
      expect(group.can_show_assigned_tab?).to eq(true)
    end

    it "returns true when assignable_level is everyone" do
      group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])
      expect(group.can_show_assigned_tab?).to eq(true)
    end

    it "does not depend on group members being in assign_allowed_on_groups" do
      user = Fabricate(:user)
      group.update!(assignable_level: Group::ALIAS_LEVELS[:everyone])
      group.add(user)
      expect(group.can_show_assigned_tab?).to eq(true)
    end
  end
end
