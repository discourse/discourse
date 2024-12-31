# frozen_string_literal: true

RSpec.describe UserAssociatedGroup do
  fab!(:group)
  fab!(:associated_group)
  fab!(:user)
  fab!(:gag) do
    GroupAssociatedGroup.create(group_id: group.id, associated_group_id: associated_group.id)
  end
  fab!(:uag) { described_class.create(user_id: user.id, associated_group_id: associated_group.id) }

  let(:group2) { Fabricate(:group) }
  let(:associated_group2) { Fabricate(:associated_group) }

  it "adds user to group when created" do
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes user from group when destroyed" do
    uag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end

  it "does not remove user with multiple associations from group when destroyed" do
    GroupAssociatedGroup.create(group_id: group.id, associated_group_id: associated_group2.id)
    described_class.create(user_id: user.id, associated_group_id: associated_group2.id)

    uag.destroy!
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes users with multiple associations to other groups when destroyed" do
    GroupAssociatedGroup.create(group_id: group2.id, associated_group_id: associated_group2.id)
    described_class.create(user_id: user.id, associated_group_id: associated_group2.id)

    uag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end
end
