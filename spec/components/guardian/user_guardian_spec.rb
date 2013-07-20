require 'spec_helper'

describe UserGuardian do
  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }
  let(:another_admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }

  describe 'can_impersonate?' do
    it 'allows impersonation correctly' do
      Guardian.new(admin).can_impersonate?(nil).should be_false
      Guardian.new.can_impersonate?(user).should be_false
      Guardian.new(coding_horror).can_impersonate?(user).should be_false
      Guardian.new(admin).can_impersonate?(admin).should be_false
      Guardian.new(admin).can_impersonate?(another_admin).should be_false
      Guardian.new(admin).can_impersonate?(user).should be_true
      Guardian.new(admin).can_impersonate?(moderator).should be_true
    end
  end

  describe 'can_ban?' do
    it 'returns false when a user tries to ban another user' do
      Guardian.new(user).can_ban?(coding_horror).should be_false
    end

    it 'returns true when an admin tries to ban another user' do
      Guardian.new(admin).can_ban?(coding_horror).should be_true
    end

    it 'returns true when a moderator tries to ban another user' do
      Guardian.new(moderator).can_ban?(coding_horror).should be_true
    end

    it 'returns false when staff tries to ban staff' do
      Guardian.new(admin).can_ban?(moderator).should be_false
    end
  end

  describe 'can_revoke_admin?' do
    it "wont allow a non logged in user to revoke an admin's access" do
      Guardian.new.can_revoke_admin?(another_admin).should be_false
    end

    it "wont allow a regular user to revoke an admin's access" do
      Guardian.new(user).can_revoke_admin?(another_admin).should be_false
    end

    it 'wont allow an admin to revoke their own access' do
      Guardian.new(admin).can_revoke_admin?(admin).should be_false
    end

    it "allows an admin to revoke another admin's access" do
      admin.id = 1
      another_admin.id = 2

      Guardian.new(admin).can_revoke_admin?(another_admin).should be_true
    end
  end

  describe 'can_grant_admin?' do
    it "wont allow a non logged in user to grant an admin's access" do
      Guardian.new.can_grant_admin?(another_admin).should be_false
    end

    it "wont allow a regular user to revoke an admin's access" do
      Guardian.new(user).can_grant_admin?(another_admin).should be_false
    end

    it 'wont allow an admin to grant their own access' do
      Guardian.new(admin).can_grant_admin?(admin).should be_false
    end

    it "allows an admin to grant a regular user access" do
      admin.id = 1
      user.id = 2
      Guardian.new(admin).can_grant_admin?(user).should be_true
    end
  end

  describe 'can_revoke_moderation?' do
    it "wont allow a non logged in user to revoke an moderator's access" do
      Guardian.new.can_revoke_moderation?(moderator).should be_false
    end

    it "wont allow a regular user to revoke an moderator's access" do
      Guardian.new(user).can_revoke_moderation?(moderator).should be_false
    end

    it 'wont allow a moderator to revoke their own moderator' do
      Guardian.new(moderator).can_revoke_moderation?(moderator).should be_false
    end

    it "allows an admin to revoke a moderator's access" do
      Guardian.new(admin).can_revoke_moderation?(moderator).should be_true
    end

    it "allows an admin to revoke a moderator's access from self" do
      admin.moderator = true
      Guardian.new(admin).can_revoke_moderation?(admin).should be_true
    end

    it "does not allow revoke from non moderators" do
      Guardian.new(admin).can_revoke_moderation?(admin).should be_false
    end
  end

  describe 'can_grant_moderation?' do
    it "wont allow a non logged in user to grant an moderator's access" do
      Guardian.new.can_grant_moderation?(user).should be_false
    end

    it "wont allow a regular user to revoke an moderator's access" do
      Guardian.new(user).can_grant_moderation?(moderator).should be_false
    end

    it 'will allow an admin to grant their own moderator access' do
      Guardian.new(admin).can_grant_moderation?(admin).should be_true
    end

    it 'wont allow an admin to grant it to an already moderator' do
      Guardian.new(admin).can_grant_moderation?(moderator).should be_false
    end

    it "allows an admin to grant a regular user access" do
      Guardian.new(admin).can_grant_moderation?(user).should be_true
    end
  end

  describe 'can_grant_title?' do
    it 'is false without a logged in user' do
      Guardian.new(nil).can_grant_title?(user).should be_false
    end

    it 'is false for regular users' do
      Guardian.new(user).can_grant_title?(user).should be_false
    end

    it 'is true for moderators' do
      Guardian.new(moderator).can_grant_title?(user).should be_true
    end

    it 'is true for admins' do
      Guardian.new(admin).can_grant_title?(user).should be_true
    end

    it 'is false without a user to look at' do
      Guardian.new(admin).can_grant_title?(nil).should be_false
    end
  end

  describe "can_delete_user?" do
    it "is false without a logged in user" do
      Guardian.new(nil).can_delete_user?(user).should be_false
    end

    it "is false without a user to look at" do
      Guardian.new(admin).can_delete_user?(nil).should be_false
    end

    it "is false for regular users" do
      Guardian.new(user).can_delete_user?(coding_horror).should be_false
    end

    it "is false for moderators" do
      Guardian.new(moderator).can_delete_user?(coding_horror).should be_false
    end

    context "for admins" do
      it "is false if user has posts" do
        Fabricate(:post, user: user)
        Guardian.new(admin).can_delete_user?(user).should be_false
      end

      it "is true if user has no posts" do
        Guardian.new(admin).can_delete_user?(user).should be_true
      end
    end
  end

  describe 'can_edit_user?' do
    it 'returns false when not logged in' do
      Guardian.new.can_edit?(user).should be_false
    end

    it 'returns false as a different user' do
      Guardian.new(coding_horror).can_edit?(user).should be_false
    end

    it 'returns true when trying to edit yourself' do
      Guardian.new(user).can_edit?(user).should be_true
    end

    it 'returns true as a moderator' do
      Guardian.new(moderator).can_edit?(user).should be_true
    end

    it 'returns true as an admin' do
      Guardian.new(admin).can_edit?(user).should be_true
    end
  end
end
