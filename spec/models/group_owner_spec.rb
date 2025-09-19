# frozen_string_literal: true

RSpec.describe GroupOwner do
  fab!(:group)
  fab!(:user)

  describe "associations" do
    it { is_expected.to belong_to(:group) }
    it { is_expected.to belong_to(:user) }
  end

  describe "validations" do
    it "validates uniqueness of group_id scoped to user_id" do
      GroupOwner.create!(group: group, user: user)
      duplicate = GroupOwner.new(group: group, user: user)
      
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:group_id]).to include("has already been taken")
    end
  end

  describe "callbacks" do
    it "triggers owner added event on create" do
      expect(DiscourseEvent).to receive(:trigger).with(:user_added_as_group_owner, user, group)
      
      GroupOwner.create!(group: group, user: user)
    end

    it "triggers owner removed event on destroy" do
      group_owner = GroupOwner.create!(group: group, user: user)
      
      expect(DiscourseEvent).to receive(:trigger).with(:user_removed_as_group_owner, user, group)
      
      group_owner.destroy!
    end
  end
end