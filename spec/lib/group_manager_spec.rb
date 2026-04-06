# frozen_string_literal: true

RSpec.describe GroupManager do
  fab!(:group)
  fab!(:user)
  fab!(:user2, :user)

  subject(:manager) { GroupManager.new(group) }

  describe "#add" do
    it "adds users to group and returns added user IDs" do
      result = manager.add([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id, user2.id)
    end

    it "returns empty array for blank input" do
      expect(manager.add([])).to eq([])
      expect(manager.add(nil)).to eq([])
    end
  end

  describe "#remove" do
    before { manager.add([user.id, user2.id]) }

    it "removes users from group and returns removed user IDs" do
      result = manager.remove([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.count).to eq(0)
    end

    it "returns empty array for blank input" do
      expect(manager.remove([])).to eq([])
      expect(manager.remove(nil)).to eq([])
    end
  end
end
