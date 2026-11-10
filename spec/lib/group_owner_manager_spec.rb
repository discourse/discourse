# frozen_string_literal: true

describe GroupOwnerManager do
  fab!(:admin)
  fab!(:owner, :user)
  fab!(:user)
  fab!(:group)

  before { group.add_owner(owner) }

  describe ".add" do
    it "makes a user an owner and adds them as a member" do
      result = described_class.add(owner.guardian, group, usernames: user.username)

      expect(result[:usernames]).to eq([user.username])
      expect(group.group_users.find_by(user:).owner).to eq(true)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:make_user_group_owner],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "notifies the new owner only when asked" do
      expect {
        described_class.add(owner.guardian, group, usernames: user.username)
      }.not_to change { Topic.private_messages.count }

      expect_enqueued_with(
        job: :notify_users_added_to_group,
        args: {
          user_ids: [user.id],
          group_id: group.id,
          owner: true,
        },
      ) do
        expect do
          described_class.add(admin.guardian, group, usernames: user.username, notify_users: true)
        end.not_to change { Topic.private_messages.count }
      end
    end

    it "refuses an automatic group" do
      automatic = Group.find(Group::AUTO_GROUPS[:trust_level_1])

      expect {
        described_class.add(admin.guardian, automatic, usernames: user.username)
      }.to raise_error(GroupMutations::AutomaticGroup)
    end

    it "refuses a user who cannot edit the group" do
      expect { described_class.add(user.guardian, group, usernames: user.username) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end
  end

  describe ".remove" do
    it "revokes ownership but keeps the membership" do
      group.add_owner(user)

      result = described_class.remove(admin.guardian, group, usernames: user.username)

      expect(result[:usernames]).to eq([user.username])
      expect(group.group_users.find_by(user:).owner).to eq(false)
      expect(group.reload.users).to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:remove_user_as_group_owner],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "requires a selector" do
      expect { described_class.remove(admin.guardian, group) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
