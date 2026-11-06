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

    it "refuses email invitations before adding users when the owner cannot invite" do
      SiteSetting.invite_allowed_groups = Group::AUTO_GROUPS[:staff]

      [user.email, "newcomer@example.com"].each do |email|
        expect do
          described_class.add(owner.guardian, group, usernames: user.username, emails: email)
        end.to raise_error(GroupMemberAdder::EmailsNotAllowed)
      end
      expect(group.users).not_to include(user)
      expect(Invite.where(invited_by: owner)).to be_empty
    end

    it "refuses to add another staff account to a group whose settings would change it" do
      category = Fabricate(:category)
      tag = Fabricate(:tag)
      groups = [
        Fabricate(:group, primary_group: true),
        Fabricate(:group, title: "Docs team"),
        Fabricate(:group, grant_trust_level: 3),
        Fabricate(:group).tap do |configured|
          GroupCategoryNotificationDefault.create!(
            group: configured,
            category:,
            notification_level: NotificationLevels.all[:watching],
          )
        end,
        Fabricate(:group).tap do |configured|
          GroupTagNotificationDefault.create!(
            group: configured,
            tag:,
            notification_level: NotificationLevels.all[:watching],
          )
        end,
      ]

      groups.each do |configured_group|
        configured_group.add_owner(owner)

        expect {
          described_class.add(
            owner.guardian,
            configured_group,
            usernames: [user.username, admin.username],
          )
        }.to raise_error(Discourse::InvalidAccess)

        expect(configured_group.reload.users).to contain_exactly(owner)
      end
      expect(admin.reload.primary_group_id).to eq(nil)
      expect(admin.title).to eq(nil)
    end

    it "does not let a moderator add a peer moderator to a primary group" do
      SiteSetting.moderators_manage_groups = true
      moderator = Fabricate(:moderator)
      peer_moderator = Fabricate(:moderator)
      group.update!(primary_group: true)

      expect {
        described_class.add(moderator.guardian, group, usernames: peer_moderator.username)
      }.to raise_error(Discourse::InvalidAccess)

      expect(peer_moderator.reload.primary_group_id).to eq(nil)
    end

    it "adds another staff account to a group whose settings leave it unchanged" do
      described_class.add(owner.guardian, group, usernames: admin.username)

      expect(group.reload.users).to include(admin)
    end

    it "adds regular users to a primary group that staff accounts already belong to" do
      group.update!(primary_group: true)
      group.add(admin)

      described_class.add(owner.guardian, group, usernames: [user.username, admin.username])

      expect(user.reload.primary_group_id).to eq(group.id)
    end

    it "lets admins, and moderators adding themselves, add staff accounts to a primary group" do
      SiteSetting.moderators_manage_groups = true
      moderator = Fabricate(:moderator)
      group.update!(primary_group: true)

      described_class.add(moderator.guardian, group, usernames: moderator.username)
      described_class.add(admin.guardian, group, usernames: Fabricate(:moderator).username)

      expect(group.reload.users.where(moderator: true).pluck(:primary_group_id)).to eq(
        [group.id, group.id],
      )
    end
  end
end
