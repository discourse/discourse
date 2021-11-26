# frozen_string_literal: true

require 'rails_helper'

describe GroupAssociatedGroup do
  let(:user) { Fabricate(:user) }
  let(:group) { Fabricate(:group) }
  let(:group2) { Fabricate(:group) }
  let(:associated_group) { Fabricate(:associated_group) }
  let(:associated_group2) { Fabricate(:associated_group) }

  before do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group.id)
    @gag = described_class.create(group_id: group.id, associated_group_id: associated_group.id)
  end

  it "adds users to group when created" do
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes users from group when destroyed" do
    @gag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end

  it "does not remove users with multiple associations to group when destroyed" do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group2.id)
    described_class.create(group_id: group.id, associated_group_id: associated_group2.id)

    @gag.destroy!
    expect(group.users.include?(user)).to eq(true)
  end

  it "removes users with multiple associations to other groups when destroyed" do
    UserAssociatedGroup.create(user_id: user.id, associated_group_id: associated_group2.id)
    described_class.create(group_id: group2.id, associated_group_id: associated_group2.id)

    @gag.destroy!
    expect(group.users.include?(user)).to eq(false)
  end
end
