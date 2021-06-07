# frozen_string_literal: true

require 'rails_helper'

describe InviteRedeemer do

  describe '#create_user_from_invite' do
    it "should be created correctly" do
      invite = Fabricate(:invite, email: 'walter.white@email.com')
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White')
      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user.email).to eq('walter.white@email.com')
      expect(user.approved).to eq(true)
      expect(user.active).to eq(false)
    end

    it "can set the password and ip_address" do
      password = 's3cure5tpasSw0rD'
      ip_address = '192.168.1.1'
      invite = Fabricate(:invite, email: 'walter.white@email.com')
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White', password: password, ip_address: ip_address)
      expect(user).to have_password
      expect(user.confirm_password?(password)).to eq(true)
      expect(user.approved).to eq(true)
      expect(user.ip_address).to eq(ip_address)
      expect(user.registration_ip_address).to eq(ip_address)
    end

    it "raises exception with record and errors" do
      error = nil
      invite = Fabricate(:invite, email: 'walter.white@email.com')
      begin
        InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White', password: 'aaa')
      rescue ActiveRecord::RecordInvalid => e
        error = e
      end
      expect(error).to be_present
      expect(error.record.errors[:password]).to be_present
    end

    it "should unstage user" do
      staged_user = Fabricate(:staged, email: 'staged@account.com', active: true, username: 'staged1', name: 'Stage Name')
      invite = Fabricate(:invite, email: 'staged@account.com')
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White')

      expect(user.id).to eq(staged_user.id)
      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user.staged).to eq(false)
      expect(user.email).to eq('staged@account.com')
      expect(user.approved).to eq(true)
    end

    it "activates user invited via email with a token" do
      invite = Fabricate(:invite, invited_by: Fabricate(:admin), email: 'walter.white@email.com', emailed_status: Invite.emailed_status_types[:sent])
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White', email_token: invite.email_token)

      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user.email).to eq('walter.white@email.com')
      expect(user.approved).to eq(true)
      expect(user.active).to eq(true)
    end

    it "does not activate user invited via email with a wrong token" do
      invite = Fabricate(:invite, invited_by: Fabricate(:user), email: 'walter.white@email.com', emailed_status: Invite.emailed_status_types[:sent])
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White', email_token: 'wrong_token')
      expect(user.active).to eq(false)
    end

    it "does not activate user invited via email without a token" do
      invite = Fabricate(:invite, invited_by: Fabricate(:user), email: 'walter.white@email.com', emailed_status: Invite.emailed_status_types[:sent])
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White')
      expect(user.active).to eq(false)
    end

    it "does not activate user invited via links" do
      invite = Fabricate(:invite, email: 'walter.white@email.com', emailed_status: Invite.emailed_status_types[:not_required])
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'walter', name: 'Walter White')

      expect(user.username).to eq('walter')
      expect(user.name).to eq('Walter White')
      expect(user.email).to eq('walter.white@email.com')
      expect(user.approved).to eq(true)
      expect(user.active).to eq(false)
    end

    it "does not automatically approve users if must_approve_users is true" do
      SiteSetting.must_approve_users = true

      invite = Fabricate(:invite, email: 'test@example.com')
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'test')
      expect(user.approved).to eq(false)
    end

    it "approves user if invited by staff" do
      SiteSetting.must_approve_users = true

      invite = Fabricate(:invite, email: 'test@example.com', invited_by: Fabricate(:admin))
      user = InviteRedeemer.create_user_from_invite(invite: invite, email: invite.email, username: 'test')
      expect(user.approved).to eq(true)
    end
  end

  describe "#redeem" do
    fab!(:invite) { Fabricate(:invite, email: "foobar@example.com") }
    let(:name) { 'john snow' }
    let(:username) { 'kingofthenorth' }
    let(:password) { 'know5nOthiNG' }
    let(:invite_redeemer) { InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name) }

    it "should redeem the invite if invited by staff" do
      SiteSetting.must_approve_users = true
      inviter = invite.invited_by
      inviter.admin = true
      user = invite_redeemer.redeem
      invite.reload

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(true)
    end

    it "should redeem the invite if invited by non staff but not approve" do
      SiteSetting.must_approve_users = true
      inviter = invite.invited_by
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(false)
    end

    it "should redeem the invite if invited by non staff and approve if staff not required to approve" do
      inviter = invite.invited_by
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(user.approved).to eq(true)
    end

    it "should redeem the invite if invited by non staff and approve if email in auto_approve_email_domains setting" do
      SiteSetting.must_approve_users = true
      SiteSetting.auto_approve_email_domains = "example.com"
      user = invite_redeemer.redeem

      expect(user.name).to eq(name)
      expect(user.username).to eq(username)
      expect(user.approved).to eq(true)
    end

    it "should delete invite if invited_by user has been removed" do
      invite.invited_by.destroy!
      expect { invite.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it "can set password" do
      user = InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name, password: password).redeem
      expect(user).to have_password
      expect(user.confirm_password?(password)).to eq(true)
      expect(user.approved).to eq(true)
    end

    it "can set custom fields" do
      required_field = Fabricate(:user_field)
      optional_field = Fabricate(:user_field, required: false)
      user_fields = {
        required_field.id.to_s => 'value1',
        optional_field.id.to_s => 'value2'
      }
      user = InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name, password: password, user_custom_fields: user_fields).redeem

      expect(user).to be_present
      expect(user.custom_fields["user_field_#{required_field.id}"]).to eq('value1')
      expect(user.custom_fields["user_field_#{optional_field.id}"]).to eq('value2')
    end

    it "does not add user to group if inviter does not have permissions" do
      group = Fabricate(:group, grant_trust_level: 2)
      InvitedGroup.create(group_id: group.id, invite_id: invite.id)
      user = InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name, password: password).redeem

      expect(user.group_users.count).to eq(0)
    end

    it "adds user to group" do
      group = Fabricate(:group, grant_trust_level: 2)
      InvitedGroup.create(group_id: group.id, invite_id: invite.id)
      group.add_owner(invite.invited_by)

      user = InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name, password: password).redeem

      expect(user.group_users.count).to eq(4)
      expect(user.trust_level).to eq(2)
    end

    it "only allows one user to be created per invite" do
      user = invite_redeemer.redeem
      invite.reload

      user.email = "john@example.com"
      user.save!

      another_invite_redeemer = InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name)
      another_user = another_invite_redeemer.redeem
      expect(another_user).to eq(nil)
    end

    it "should correctly update the invite redeemed_at date" do
      SiteSetting.invite_expiry_days = 2
      invite.update!(created_at: 10.days.ago)

      inviter = invite.invited_by
      inviter.admin = true
      user = invite_redeemer.redeem
      invite.reload

      expect(user.invited_by).to eq(inviter)
      expect(inviter.notifications.count).to eq(1)
      expect(invite.invited_users.first).to be_present
    end

    context "ReviewableUser" do
      it "approves pending record" do
        reviewable = ReviewableUser.needs_review!(target: Fabricate(:user, email: invite.email), created_by: invite.invited_by)
        reviewable.status = Reviewable.statuses[:pending]
        reviewable.save!
        invite_redeemer.redeem

        reviewable.reload
        expect(reviewable.status).to eq(Reviewable.statuses[:approved])
      end

      it "does not raise error if record is not pending" do
        reviewable = ReviewableUser.needs_review!(target: Fabricate(:user, email: invite.email), created_by: invite.invited_by)
        reviewable.status = Reviewable.statuses[:ignored]
        reviewable.save!
        invite_redeemer.redeem

        reviewable.reload
        expect(reviewable.status).to eq(Reviewable.statuses[:ignored])
      end
    end

    context 'invite_link' do
      fab!(:invite_link) { Fabricate(:invite, email: nil, max_redemptions_allowed: 5, expires_at: 1.month.from_now, emailed_status: Invite.emailed_status_types[:not_required]) }
      let(:invite_redeemer) { InviteRedeemer.new(invite: invite_link, email: 'foo@example.com') }

      it 'works as expected' do
        user = invite_redeemer.redeem
        invite_link.reload

        expect(user.send_welcome_message).to eq(true)
        expect(user.trust_level).to eq(SiteSetting.default_invitee_trust_level)
        expect(user.active).to eq(false)
        expect(invite_link.redemption_count).to eq(1)
      end

      it "should not redeem the invite if InvitedUser record already exists for email" do
        user = invite_redeemer.redeem
        invite_link.reload

        another_invite_redeemer = InviteRedeemer.new(invite: invite_link, email: 'foo@example.com')
        another_user = another_invite_redeemer.redeem
        expect(another_user).to eq(nil)
      end

      it "should redeem the invite if InvitedUser record does not exists for email" do
        user = invite_redeemer.redeem
        invite_link.reload

        another_invite_redeemer = InviteRedeemer.new(invite: invite_link, email: 'bar@example.com')
        another_user = another_invite_redeemer.redeem
        expect(another_user.is_a?(User)).to eq(true)
      end
    end

  end
end
