require 'spec_helper'
require_dependency 'post_destroyer'

describe Guardian do
  let(:user) { build(:user) }
  let(:moderator) { build(:moderator) }
  let(:admin) { build(:admin) }
  let(:another_admin) { build(:admin) }
  let(:coding_horror) { build(:coding_horror) }

  let(:topic) { build(:topic, user: user) }
  let(:post) { build(:post, topic: topic, user: topic.user) }

  it 'can be created without a user (not logged in)' do
    lambda { Guardian.new }.should_not raise_error
  end

  it 'can be instantiated with a user instance' do
    lambda { Guardian.new(user) }.should_not raise_error
  end

  describe 'can_moderate?' do
    it 'returns false with a nil object' do
      Guardian.new(user).can_moderate?(nil).should be_false
    end

    context 'a Topic' do
      it 'returns false when not logged in' do
        Guardian.new.can_moderate?(topic).should be_false
      end

      it 'returns false when not a moderator' do
        Guardian.new(user).can_moderate?(topic).should be_false
      end

      it 'returns true when a moderator' do
        Guardian.new(moderator).can_moderate?(topic).should be_true
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_moderate?(topic).should be_true
      end
    end
  end

  describe 'can_move_posts?' do
    it 'returns false with a nil object' do
      Guardian.new(user).can_move_posts?(nil).should be_false
    end

    context 'a Topic' do
      it 'returns false when not logged in' do
        Guardian.new.can_move_posts?(topic).should be_false
      end

      it 'returns false when not a moderator' do
        Guardian.new(user).can_move_posts?(topic).should be_false
      end

      it 'returns true when a moderator' do
        Guardian.new(moderator).can_move_posts?(topic).should be_true
      end

      it 'returns true when an admin' do
        Guardian.new(admin).can_move_posts?(topic).should be_true
      end
    end
  end

  describe 'can_see_flags?' do
    it "returns false when there is no post" do
      Guardian.new(moderator).can_see_flags?(nil).should be_false
    end

    it "returns false when there is no user" do
      Guardian.new(nil).can_see_flags?(post).should be_false
    end

    it "allow regular uses to see flags" do
      Guardian.new(user).can_see_flags?(post).should be_false
    end

    it "allows moderators to see flags" do
      Guardian.new(moderator).can_see_flags?(post).should be_true
    end

    it "allows moderators to see flags" do
      Guardian.new(admin).can_see_flags?(post).should be_true
    end
  end

  describe 'can_approve?' do
    it "wont allow a non-logged in user to approve" do
      Guardian.new.can_approve?(user).should be_false
    end

    it "wont allow a non-admin to approve a user" do
      Guardian.new(coding_horror).can_approve?(user).should be_false
    end

    it "returns false when the user is already approved" do
      user.approved = true
      Guardian.new(admin).can_approve?(user).should be_false
    end

    it "allows an admin to approve a user" do
      Guardian.new(admin).can_approve?(user).should be_true
    end

    it "allows a moderator to approve a user" do
      Guardian.new(moderator).can_approve?(user).should be_true
    end
  end

  describe "can_access_forum?" do
    let(:unapproved_user) { Fabricate.build(:user) }

    context "when must_approve_users is false" do
      before do
        SiteSetting.stubs(:must_approve_users?).returns(false)
      end

      it "returns true for a nil user" do
        Guardian.new(nil).can_access_forum?.should be_true
      end

      it "returns true for an unapproved user" do
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end
    end

    context 'when must_approve_users is true' do
      before do
        SiteSetting.stubs(:must_approve_users?).returns(true)
      end

      it "returns false for a nil user" do
        Guardian.new(nil).can_access_forum?.should be_false
      end

      it "returns false for an unapproved user" do
        Guardian.new(unapproved_user).can_access_forum?.should be_false
      end

      it "returns true for an admin user" do
        unapproved_user.admin = true
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end

      it "returns true for an approved user" do
        unapproved_user.approved = true
        Guardian.new(unapproved_user).can_access_forum?.should be_true
      end
    end
  end

  describe "can_see_pending_invites_from?" do
    it 'is false without a logged in user' do
      Guardian.new(nil).can_see_pending_invites_from?(user).should be_false
    end

    it 'is false without a user to look at' do
      Guardian.new(user).can_see_pending_invites_from?(nil).should be_false
    end

    it 'is true when looking at your own invites' do
      Guardian.new(user).can_see_pending_invites_from?(user).should be_true
    end
  end

  describe 'can_send_private_message' do
    let(:user) { Fabricate(:user) }
    let(:another_user) { Fabricate(:user) }

    it "returns false when the user is nil" do
      Guardian.new(nil).can_send_private_message?(user).should be_false
    end

    it "returns false when the target user is nil" do
      Guardian.new(user).can_send_private_message?(nil).should be_false
    end

    it "returns false when the target is the same as the user" do
      Guardian.new(user).can_send_private_message?(user).should be_false
    end

    it "returns false when you are untrusted" do
      user.trust_level = TrustLevel.levels[:new]
      Guardian.new(user).can_send_private_message?(another_user).should be_false
    end

    it "returns true to another user" do
      Guardian.new(user).can_send_private_message?(another_user).should be_true
    end
  end

  describe 'can_see?' do
    it 'returns false with a nil object' do
      Guardian.new.can_see?(nil).should be_false
    end
  end

  describe 'can_edit?' do
    it 'returns false with a nil object' do
      Guardian.new(user).can_edit?(nil).should be_false
    end
  end

  describe 'can_delete?' do
    it 'returns false with a nil object' do
      Guardian.new(user).can_delete?(nil).should be_false
    end
  end
end

