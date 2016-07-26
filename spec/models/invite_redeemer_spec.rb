require 'rails_helper'

describe InviteRedeemer do

  describe '#create_user_from_invite' do
    let(:user) { InviteRedeemer.create_user_from_invite(Fabricate(:invite, email: 'walter.white@email.com'), 'walter', 'Walter White') }

    it "should be created correctly" do
      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user).to be_active
      expect(user.email).to eq('walter.white@email.com')
    end
  end

  describe "#redeem" do
    let(:invite) { Fabricate(:invite) }
    let(:name) { 'john snow' }
    let(:username) { 'kingofthenorth' }
    let(:invite_redeemer) { InviteRedeemer.new(invite, username, name) }

    it "should redeem the invite" do
      inviter = invite.invited_by
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
    end

    it "should not blow up if invited_by user has been removed" do
      invite.invited_by.destroy!
      invite.reload

      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(nil)
    end
  end
end
