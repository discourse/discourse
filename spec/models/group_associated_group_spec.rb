# frozen_string_literal: true

RSpec.describe GroupAssociatedGroup do
  fab!(:user)
  fab!(:group)
  fab!(:group2) { Fabricate(:group) }
  fab!(:associated_group)
  fab!(:associated_group2) { Fabricate(:associated_group) }
  fab!(:uag) do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group.id)
  end
  fab!(:gag) do
    described_class.create(group_id: group.id, associated_group_id: associated_group.id)
  end

  it "adds users to group when created" do
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes users from group when destroyed" do
    gag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end

  it "does not remove users with multiple associations to group when destroyed" do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group2.id)
    described_class.create(group_id: group.id, associated_group_id: associated_group2.id)

    gag.destroy!
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes users with multiple associations to other groups when destroyed" do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group2.id)
    described_class.create(group_id: group2.id, associated_group_id: associated_group2.id)

    gag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end
end
