# frozen_string_literal: true

describe GroupDestroyer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  fab!(:group)

  describe ".destroy" do
    it "deletes the group and logs the deletion" do
      expect { described_class.destroy(admin.guardian, group) }.to change { Group.count }.by(-1)

      expect(
        UserHistory.exists?(action: UserHistory.actions[:delete_group], acting_user_id: admin.id),
      ).to eq(true)
    end

    it "refuses an automatic group" do
      automatic = Group.find(Group::AUTO_GROUPS[:trust_level_1])

      expect { described_class.destroy(admin.guardian, automatic) }.to raise_error(
        GroupMutations::AutomaticGroup,
      )
    end

    it "refuses a moderator even when moderators manage groups" do
      SiteSetting.moderators_manage_groups = true

      expect { described_class.destroy(moderator.guardian, group) }.to raise_error(
        Discourse::InvalidAccess,
      )
      expect(Group.exists?(group.id)).to eq(true)
    end

    it "refuses a regular user" do
      expect { described_class.destroy(user.guardian, group) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end
  end
end
