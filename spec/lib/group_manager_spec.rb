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

  describe "user_count" do
    fab!(:bot)

    it "counts bots in automatic groups not created by core" do
      automatic_group = Fabricate(:group, automatic: true)
      automatic_manager = GroupManager.new(automatic_group)

      expect { automatic_manager.add([user.id, bot.id]) }.to change {
        automatic_group.reload.user_count
      }.by(2)
      expect { automatic_manager.remove([bot.id]) }.to change {
        automatic_group.reload.user_count
      }.by(-1)
    end

    it "does not count bots in hand-managed groups" do
      expect { manager.add([user.id, bot.id]) }.to change { group.reload.user_count }.by(1)
      expect { manager.remove([bot.id]) }.not_to change { group.reload.user_count }
    end

    it "does not count bots in core automatic groups" do
      staff_manager = GroupManager.new(Group[:staff])

      expect { staff_manager.add([user.id, bot.id]) }.to change { Group[:staff].user_count }.by(1)
      expect { staff_manager.remove([bot.id]) }.not_to change { Group[:staff].user_count }
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
