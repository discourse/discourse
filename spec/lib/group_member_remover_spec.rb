# frozen_string_literal: true

describe GroupMemberRemover do
  fab!(:owner, :user)
  fab!(:user)
  fab!(:user_1, :user)
  fab!(:group)

  before do
    group.add_owner(owner)
    group.add(user)
  end

  describe ".remove" do
    it "removes members and logs the change" do
      result = described_class.remove(owner.guardian, group, usernames: user.username)

      expect(result[:usernames]).to eq([user.username])
      expect(result[:skipped_usernames]).to be_empty
      expect(group.reload.users).not_to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:remove_user_from_group],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "reports users who were not members as skipped" do
      result =
        described_class.remove(owner.guardian, group, usernames: [user.username, user_1.username])

      expect(result[:usernames]).to eq([user.username])
      expect(result[:skipped_usernames]).to eq([user_1.username])
    end

    it "refuses a user who cannot edit the group" do
      expect {
        described_class.remove(user_1.guardian, group, usernames: user.username)
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "requires a selector" do
      expect { described_class.remove(owner.guardian, group) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end
  end
end
