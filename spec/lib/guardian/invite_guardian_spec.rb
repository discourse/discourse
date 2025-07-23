# frozen_string_literal: true

RSpec.describe InviteGuardian do
  fab!(:user)
  fab!(:admin)
  fab!(:moderator)
  fab!(:trust_level_1)
  fab!(:trust_level_2)

  fab!(:group)
  fab!(:another_group, :group)
  fab!(:automatic_group) { Fabricate(:group, automatic: true) }

  fab!(:topic) { Fabricate(:topic, user: user) }

  ###### VISIBILITY ######

  describe "#can_see_invite_details?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_see_invite_details?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(user).can_see_invite_details?(nil)).to be_falsey
    end

    it "is true when looking at your own invites" do
      expect(Guardian.new(user).can_see_invite_details?(user)).to be_truthy
    end
  end

  describe "#can_see_invite_emails?" do
    it "is false without a logged in user" do
      expect(Guardian.new(nil).can_see_invite_emails?(user)).to be_falsey
    end

    it "is false without a user to look at" do
      expect(Guardian.new(user).can_see_invite_emails?(nil)).to be_falsey
    end

    it "is true when looking at your own invites" do
      expect(Guardian.new(user).can_see_invite_emails?(user)).to be_truthy
    end
  end

  ###### INVITING ######

  describe "#can_invite_to_forum?" do
    it "returns true if user has sufficient trust level" do
      SiteSetting.invite_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(Guardian.new(trust_level_2).can_invite_to_forum?).to be_truthy
      expect(Guardian.new(moderator).can_invite_to_forum?).to be_truthy
    end

    it "returns false if user trust level does not have sufficient trust level" do
      SiteSetting.invite_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
      expect(Guardian.new(trust_level_1).can_invite_to_forum?).to be_falsey
    end

    it "doesn't allow anonymous users to invite" do
      expect(Guardian.new.can_invite_to_forum?).to be_falsey
    end

    it "returns true when the site requires approving users" do
      SiteSetting.must_approve_users = true
      expect(Guardian.new(trust_level_2).can_invite_to_forum?).to be_truthy
    end

    it "returns false when max_invites_per_day is 0" do
      # let's also break it while here
      SiteSetting.max_invites_per_day = "a"

      expect(Guardian.new(user).can_invite_to_forum?).to be_falsey
      # staff should be immune to max_invites_per_day setting
      expect(Guardian.new(moderator).can_invite_to_forum?).to be_truthy
    end

    context "with groups" do
      let(:groups) { [group, another_group] }

      before do
        user.change_trust_level!(TrustLevel[2])
        group.add_owner(user)
      end

      it "returns false when user is not allowed to edit a group" do
        expect(Guardian.new(user).can_invite_to_forum?(groups)).to eq(false)

        expect(Guardian.new(admin).can_invite_to_forum?(groups)).to eq(true)
      end

      it "returns true when user is allowed to edit groups" do
        another_group.add_owner(user)

        expect(Guardian.new(user).can_invite_to_forum?(groups)).to eq(true)
      end
    end
  end

  describe "#can_invite_to?" do
    describe "regular topics" do
      before do
        SiteSetting.invite_allowed_groups = Group::AUTO_GROUPS[:trust_level_2]
        user.update!(trust_level: 2)
      end
      fab!(:category) { Fabricate(:category, read_restricted: true) }
      fab!(:topic)
      fab!(:private_topic) { Fabricate(:topic, category: category) }
      fab!(:user) { topic.user }
      let(:private_category) { Fabricate(:private_category, group: group) }
      let(:group_private_topic) { Fabricate(:topic, category: private_category) }
      let(:group_owner) { group_private_topic.user.tap { |u| group.add_owner(u) } }

      it "handles invitation correctly" do
        expect(Guardian.new(nil).can_invite_to?(topic)).to be_falsey
        expect(Guardian.new(moderator).can_invite_to?(nil)).to be_falsey
        expect(Guardian.new(moderator).can_invite_to?(topic)).to be_truthy
        expect(Guardian.new(trust_level_1).can_invite_to?(topic)).to be_truthy

        SiteSetting.max_invites_per_day = 0

        expect(Guardian.new(user).can_invite_to?(topic)).to be_truthy
        # staff should be immune to max_invites_per_day setting
        expect(Guardian.new(moderator).can_invite_to?(topic)).to be_truthy
      end

      it "returns false for normal user on private topic" do
        expect(Guardian.new(user).can_invite_to?(private_topic)).to be_falsey
      end

      it "returns false for admin on private topic" do
        expect(Guardian.new(admin).can_invite_to?(private_topic)).to be(false)
      end

      it "returns true for a group owner" do
        group_owner.update!(trust_level: 2)
        expect(Guardian.new(group_owner).can_invite_to?(group_private_topic)).to be_truthy
      end

      it "return true for normal users even if must_approve_users" do
        SiteSetting.must_approve_users = true
        expect(Guardian.new(user).can_invite_to?(topic)).to be_truthy
        expect(Guardian.new(admin).can_invite_to?(topic)).to be_truthy
      end

      describe "for a private category for automatic and non-automatic group" do
        let(:category) do
          Fabricate(:category, read_restricted: true).tap do |category|
            category.groups << automatic_group
            category.groups << group
          end
        end

        let(:topic) { Fabricate(:topic, category: category) }

        it "should return true for an admin user" do
          expect(Guardian.new(admin).can_invite_to?(topic)).to eq(true)
        end

        it "should return true for a group owner" do
          group_owner.update!(trust_level: 2)
          expect(Guardian.new(group_owner).can_invite_to?(topic)).to eq(true)
        end

        it "should return false for a normal user" do
          expect(Guardian.new(user).can_invite_to?(topic)).to eq(false)
        end
      end

      describe "for a private category for automatic groups" do
        let(:category) do
          Fabricate(:private_category, group: automatic_group, read_restricted: true)
        end

        let(:group_owner) { Fabricate(:user).tap { |user| automatic_group.add_owner(user) } }
        let(:topic) { Fabricate(:topic, category: category) }

        it "should return false for all type of users" do
          expect(Guardian.new(admin).can_invite_to?(topic)).to eq(false)
          expect(Guardian.new(group_owner).can_invite_to?(topic)).to eq(false)
          expect(Guardian.new(user).can_invite_to?(topic)).to eq(false)
        end
      end
    end

    describe "private messages" do
      fab!(:user)
      fab!(:pm) { Fabricate(:private_message_topic, user: user) }

      before do
        user.change_trust_level!(TrustLevel[2])
        moderator.change_trust_level!(TrustLevel[2])
      end

      context "when private messages are disabled" do
        it "allows an admin to invite to the pm" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          expect(Guardian.new(user).can_invite_to?(pm)).to be_truthy
        end
      end

      context "when user does not belong to personal_message_enabled_groups" do
        before { SiteSetting.personal_message_enabled_groups = Group::AUTO_GROUPS[:staff] }

        it "doesn't allow a regular user to invite" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          expect(Guardian.new(user).can_invite_to?(pm)).to be_falsey
        end
      end

      context "when PM has reached the maximum number of recipients" do
        before { SiteSetting.max_allowed_message_recipients = 2 }

        it "doesn't allow a regular user to invite" do
          expect(Guardian.new(user).can_invite_to?(pm)).to be_falsey
        end

        it "allows staff to invite" do
          expect(Guardian.new(admin).can_invite_to?(pm)).to be_truthy
          pm.grant_permission_to_user(moderator.email)
          expect(Guardian.new(moderator).can_invite_to?(pm)).to be_truthy
        end
      end
    end
  end

  describe "#can_invite_via_email?" do
    it "returns true for all (tl2 and above) users when sso is disabled, local logins are enabled, user approval is not required" do
      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_truthy
    end

    it "returns true for all users when sso is enabled" do
      SiteSetting.discourse_connect_url = "https://www.example.com/sso"
      SiteSetting.enable_discourse_connect = true

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_truthy
    end

    it "returns false for all users when local logins are disabled" do
      SiteSetting.enable_local_logins = false

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_falsey
    end

    it "returns correct values when user approval is required" do
      SiteSetting.must_approve_users = true

      expect(Guardian.new(trust_level_2).can_invite_via_email?(topic)).to be_falsey
      expect(Guardian.new(moderator).can_invite_via_email?(topic)).to be_truthy
      expect(Guardian.new(admin).can_invite_via_email?(topic)).to be_truthy
    end
  end

  describe "#can_bulk_invite_to_forum?" do
    it "returns true for admin users" do
      expect(Guardian.new(admin).can_bulk_invite_to_forum?).to be_truthy
    end

    it "returns false for moderators" do
      expect(Guardian.new(moderator).can_bulk_invite_to_forum?).to be_falsey
    end

    it "returns false for regular users" do
      expect(Guardian.new(user).can_bulk_invite_to_forum?).to be_falsey
    end
  end

  ###### ACTIONS ######

  describe "#can_resend_all_invites?" do
    it "returns true for admin users" do
      expect(Guardian.new(admin).can_resend_all_invites?).to be_truthy
    end

    it "returns true for moderators" do
      expect(Guardian.new(moderator).can_resend_all_invites?).to be_truthy
    end

    it "returns false for regular users" do
      expect(Guardian.new(user).can_resend_all_invites?).to be_falsey
    end
  end

  ###### DELETION ######

  describe "#can_destroy_all_invites?" do
    it "returns true for admin users" do
      expect(Guardian.new(admin).can_destroy_all_invites?).to be_truthy
    end

    it "returns true for moderators" do
      expect(Guardian.new(moderator).can_destroy_all_invites?).to be_truthy
    end

    it "returns false for regular users" do
      expect(Guardian.new(user).can_destroy_all_invites?).to be_falsey
    end
  end
end
