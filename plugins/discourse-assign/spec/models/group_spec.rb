# frozen_string_literal: true

require "rails_helper"
require_relative "../support/assign_allowed_group"

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

  describe "includes can_show_assigned_tab? method" do
    let(:admin) { Fabricate(:admin) }
    let(:user) { Fabricate(:user) }
    let(:user1) { Fabricate(:user) }
    let(:user2) { Fabricate(:user) }

    include_context "with group that is allowed to assign"

    before do
      add_to_assign_allowed_group(user)
      add_to_assign_allowed_group(user1)
      add_to_assign_allowed_group(admin)
    end

    it "gives false in can_show_assigned_tab? when all users are not in assigned_allowed_group" do
      group.add(user)
      group.add(user1)
      group.add(user2)

      expect(group.can_show_assigned_tab?).to eq(false)
    end

    it "gives true in can_show_assigned_tab? when all users are in assigned_allowed_group" do
      group.add(user)
      group.add(user1)

      expect(group.can_show_assigned_tab?).to eq(true)
    end
  end
end
