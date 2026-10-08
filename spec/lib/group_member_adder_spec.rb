# frozen_string_literal: true

describe GroupMemberAdder do
  fab!(:admin)
  fab!(:owner, :user)
  fab!(:user)
  fab!(:user_1, :user)
  fab!(:group)

  before { group.add_owner(owner) }

  describe ".add" do
    it "adds members and logs the change" do
      result = described_class.add(owner.guardian, group, usernames: user.username)

      expect(result[:usernames]).to eq([user.username])
      expect(group.reload.users).to include(user)
      expect(
        GroupHistory.exists?(
          group:,
          action: GroupHistory.actions[:add_user_to_group],
          target_user: user,
        ),
      ).to eq(true)
    end

    it "notifies added members only when asked" do
      expect_not_enqueued_with(job: :notify_users_added_to_group) do
        described_class.add(owner.guardian, group, usernames: user.username)
      end

      expect_enqueued_with(
        job: :notify_users_added_to_group,
        args: {
          user_ids: [user_1.id],
          group_id: group.id,
        },
      ) do
        described_class.add(owner.guardian, group, usernames: user_1.username, notify_users: true)
      end
    end

    it "refuses a user who cannot edit the group" do
      expect {
        described_class.add(user.guardian, group, usernames: user_1.username)
      }.to raise_error(Discourse::InvalidAccess)
    end

    it "refuses when every selected user is already a member" do
      group.add(user)

      expect {
        described_class.add(owner.guardian, group, usernames: user.username)
      }.to raise_error(GroupMemberAdder::AlreadyMembers)
    end

    it "refuses more users than the limit allows" do
      stub_const(described_class, "LIMIT", 1) do
        expect {
          described_class.add(owner.guardian, group, usernames: [user.username, user_1.username])
        }.to raise_error(GroupMemberAdder::TooManyUsers)
      end
    end

    it "requires at least one user or email" do
      expect { described_class.add(owner.guardian, group) }.to raise_error(
        Discourse::InvalidParameters,
      )
    end

    it "adds an account that already owns the given email instead of inviting it" do
      result = described_class.add(admin.guardian, group, emails: user.email)

      expect(result[:usernames]).to eq([user.username])
      expect(result[:emails]).to be_empty
      expect(group.reload.users).to include(user)
    end

    it "invites unknown email addresses to the forum with the group preassigned" do
      result = described_class.add(admin.guardian, group, emails: "newcomer@example.com")

      expect(result[:emails]).to eq(["newcomer@example.com"])
      invite = Invite.last
      expect(invite.email).to eq("newcomer@example.com")
      expect(invite.groups).to eq([group])
    end

    it "refuses unknown email addresses when the user cannot invite" do
      SiteSetting.invite_allowed_groups = Group::AUTO_GROUPS[:staff]

      expect {
        described_class.add(owner.guardian, group, emails: "newcomer@example.com")
      }.to raise_error(Discourse::InvalidAccess)
    end
  end
end
