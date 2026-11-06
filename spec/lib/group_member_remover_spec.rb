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

    it "refuses to remove another staff account the group's settings have changed" do
      admin = Fabricate(:admin)
      primary = Fabricate(:group, primary_group: true)
      flair = Fabricate(:group, flair_icon: "star")
      titled = Fabricate(:group, title: "Docs team")
      trust_level = Fabricate(:group, grant_trust_level: 3)
      configured_groups = [primary, flair, titled, trust_level]

      configured_groups.each do |configured_group|
        configured_group.add_owner(owner)
        configured_group.add(admin)
      end
      admin.update_columns(flair_group_id: flair.id, title: "Docs team")
      expect(admin.reload.primary_group_id).to eq(primary.id)

      configured_groups.each do |configured_group|
        expect {
          described_class.remove(
            owner.guardian,
            configured_group,
            usernames: [user_1.username, admin.username],
          )
        }.to raise_error(Discourse::InvalidAccess)

        expect(configured_group.reload.users).to include(admin)
      end
      expect(admin.reload).to have_attributes(
        primary_group_id: primary.id,
        flair_group_id: flair.id,
        title: "Docs team",
      )
    end

    it "removes another staff account the group's settings have not changed" do
      admin = Fabricate(:admin)
      plain_group = Fabricate(:group)
      plain_group.add_owner(owner)
      plain_group.add(admin)

      described_class.remove(owner.guardian, plain_group, usernames: admin.username)

      group.update!(title: "Docs team", flair_icon: "star")
      group.add(admin)
      admin.update_columns(title: "Site admin")

      described_class.remove(owner.guardian, group, usernames: admin.username)

      expect(admin.reload.groups).not_to include(plain_group, group)
    end

    it "removes regular users from their primary group" do
      group.update!(primary_group: true)
      expect(user.reload.primary_group_id).to eq(group.id)

      described_class.remove(owner.guardian, group, usernames: user.username)

      expect(user.reload.primary_group_id).to eq(nil)
    end

    it "lets admins, and moderators removing themselves, remove staff accounts from their primary group" do
      SiteSetting.moderators_manage_groups = true
      moderator = Fabricate(:moderator)
      peer_moderator = Fabricate(:moderator)
      group.update!(primary_group: true)
      group.add(moderator)
      group.add(peer_moderator)

      described_class.remove(moderator.guardian, group, usernames: moderator.username)
      described_class.remove(Fabricate(:admin).guardian, group, usernames: peer_moderator.username)

      expect([moderator.reload.primary_group_id, peer_moderator.reload.primary_group_id]).to eq(
        [nil, nil],
      )
    end
  end
end
