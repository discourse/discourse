# frozen_string_literal: true

RSpec.describe GroupManager do
  fab!(:group)
  fab!(:user)
  fab!(:user2, :user)
  fab!(:acting_user, :user)

  subject(:manager) { GroupManager.new(acting_user, group) }

  describe "#add" do
    it "adds a single user and returns true" do
      expect(manager.add(user)).to eq(true)
      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id)
    end

    it "returns false for nil user" do
      expect(manager.add(nil)).to eq(false)
    end

    it "returns false when user is already in group" do
      manager.add(user)
      expect(manager.add(user)).to eq(false)
    end

    it "logs the addition to GroupHistory" do
      expect { manager.add(user) }.to change {
        GroupHistory.where(
          action: GroupHistory.actions[:add_user_to_group],
          acting_user: acting_user,
          target_user: user,
        ).count
      }.by(1)
    end

    it "skips logging when log: false" do
      expect { manager.add(user, log: false) }.not_to change { GroupHistory.count }
    end

    it "passes automatic flag through to the event" do
      events =
        DiscourseEvent.track_events(:user_added_to_group) { manager.add(user, automatic: true) }

      expect(events.first[:params][2][:automatic]).to eq(true)
    end

    it "sends notification when notify: true" do
      expect { manager.add(user, notify: true) }.to change {
        Topic.where(archetype: "private_message").count
      }.by(1)
    end

    it "does not send notification by default" do
      expect { manager.add(user) }.not_to change { Topic.where(archetype: "private_message").count }
    end

    it "records subject in GroupHistory" do
      manager.add(user, subject: "test_subject")

      expect(
        GroupHistory.find_by(
          action: GroupHistory.actions[:add_user_to_group],
          target_user: user,
        ).subject,
      ).to eq("test_subject")
    end
  end

  describe "#bulk_add" do
    it "adds multiple users and returns their IDs" do
      result = manager.bulk_add([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.map(&:user_id)).to contain_exactly(user.id, user2.id)
    end

    it "returns empty array for blank input" do
      expect(manager.bulk_add([])).to eq([])
      expect(manager.bulk_add(nil)).to eq([])
    end

    it "skips users already in the group" do
      manager.bulk_add([user.id])
      result = manager.bulk_add([user.id, user2.id])

      expect(result).to eq([user2.id])
    end

    it "logs additions to GroupHistory" do
      expect { manager.bulk_add([user.id, user2.id]) }.to change {
        GroupHistory.where(action: GroupHistory.actions[:add_user_to_group]).count
      }.by(2)
    end

    it "skips logging when log: false" do
      expect { manager.bulk_add([user.id, user2.id], log: false) }.not_to change {
        GroupHistory.count
      }
    end

    it "records subject in GroupHistory" do
      manager.bulk_add([user.id], subject: "test_subject")

      expect(
        GroupHistory.find_by(
          action: GroupHistory.actions[:add_user_to_group],
          target_user: user,
        ).subject,
      ).to eq("test_subject")
    end
  end

  describe "#remove" do
    fab!(:other_user, :user)
    before { manager.bulk_add([user.id, user2.id]) }

    it "removes a single user and returns true" do
      expect(manager.remove(user)).to eq(true)
      expect(group.group_users.map(&:user_id)).to contain_exactly(user2.id)
    end

    it "returns false for nil user" do
      expect(manager.remove(nil)).to eq(false)
    end

    it "returns false when user is not in group" do
      expect(manager.remove(other_user)).to eq(false)
    end

    it "logs the removal to GroupHistory" do
      expect { manager.remove(user) }.to change {
        GroupHistory.where(
          action: GroupHistory.actions[:remove_user_from_group],
          acting_user: acting_user,
          target_user: user,
        ).count
      }.by(1)
    end

    it "skips logging when log: false" do
      expect { manager.remove(user, log: false) }.not_to change { GroupHistory.count }
    end

    it "records subject in GroupHistory" do
      manager.remove(user, subject: "test_subject")

      expect(
        GroupHistory.find_by(
          action: GroupHistory.actions[:remove_user_from_group],
          target_user: user,
        ).subject,
      ).to eq("test_subject")
    end
  end

  describe "#bulk_remove" do
    before { manager.bulk_add([user.id, user2.id]) }

    it "removes multiple users and returns their IDs" do
      result = manager.bulk_remove([user.id, user2.id])

      expect(result).to contain_exactly(user.id, user2.id)
      expect(group.group_users.count).to eq(0)
    end

    it "returns empty array for blank input" do
      expect(manager.bulk_remove([])).to eq([])
      expect(manager.bulk_remove(nil)).to eq([])
    end

    it "ignores user_ids not in the group" do
      result = manager.bulk_remove([user.id, user2.id, user2.id + 1000])

      expect(result).to contain_exactly(user.id, user2.id)
    end

    it "logs removals to GroupHistory" do
      expect { manager.bulk_remove([user.id, user2.id]) }.to change {
        GroupHistory.where(action: GroupHistory.actions[:remove_user_from_group]).count
      }.by(2)
    end

    it "skips logging when log: false" do
      expect { manager.bulk_remove([user.id, user2.id], log: false) }.not_to change {
        GroupHistory.count
      }
    end

    it "records subject in GroupHistory" do
      manager.bulk_remove([user.id], subject: "test_subject")

      expect(
        GroupHistory.find_by(
          action: GroupHistory.actions[:remove_user_from_group],
          target_user: user,
        ).subject,
      ).to eq("test_subject")
    end
  end
end
