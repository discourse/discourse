# frozen_string_literal: true

RSpec.describe Invite do
  fab!(:user) { Fabricate(:user, email: "existinguser@invitetest.com") }
  let(:xss_email) do
    "<b onmouseover=alert('wufff!')>email</b><script>alert('test');</script>@test.com"
  end
  let(:escaped_email) do
    "&lt;b onmouseover=alert(&#39;wufff!&#39;)&gt;email&lt;/b&gt;&lt;script&gt;alert(&#39;test&#39;);&lt;/script&gt;@test.com"
  end

  describe "Validators" do
    it { is_expected.to validate_presence_of :invited_by_id }
    it { is_expected.to rate_limit }
    it { is_expected.to validate_length_of(:custom_message).is_at_most(1000) }

    it "allows invites with valid emails" do
      invite = Fabricate.build(:invite, email: "test@example.com", invited_by: user)
      expect(invite).to be_valid
    end

    it "escapes the invalid email before attaching the error message" do
      invite = Fabricate.build(:invite, email: xss_email)

      expect(invite.valid?).to eq(false)
      expect(invite.errors.full_messages).to include(
        I18n.t("invite.invalid_email", email: escaped_email),
      )
    end

    it "does not allow an invite with the same email as an existing user" do
      invite = Fabricate.build(:invite, email: Fabricate(:user).email, invited_by: user)
      expect(invite).not_to be_valid

      invite = Fabricate.build(:invite, email: user.email, invited_by: user)
      expect(invite).not_to be_valid
    end

    it "does not allow an invite with blocked email" do
      invite = Invite.create(email: "test@mailinator.com", invited_by: user)
      expect(invite).not_to be_valid
    end

    it "does not allow an invalid email address" do
      invite = Fabricate.build(:invite, email: "asjdso")
      expect(invite.valid?).to eq(false)
      expect(invite.errors.full_messages).to include(
        I18n.t("invite.invalid_email", email: invite.email),
      )
    end

    it "allows only valid domains" do
      invite = Fabricate.build(:invite, email: nil, domain: "example", invited_by: user)
      expect(invite).not_to be_valid

      invite = Fabricate.build(:invite, email: nil, domain: "example.com", invited_by: user)
      expect(invite).to be_valid
    end

    it "allows only email or only domain to be present" do
      invite = Fabricate.build(:invite, email: nil, invited_by: user)
      expect(invite).to be_valid

      invite = Fabricate.build(:invite, email: nil, domain: "example.com", invited_by: user)
      expect(invite).to be_valid

      invite = Fabricate.build(:invite, email: "test@example.com", invited_by: user)
      expect(invite).to be_valid

      invite =
        Fabricate.build(:invite, email: "test@example.com", domain: "example.com", invited_by: user)
      expect(invite).not_to be_valid
      expect(invite.errors.full_messages).to include(I18n.t("invite.email_xor_domain"))
    end

    it "checks if redemption_count is less or equal than max_redemptions_allowed" do
      invite =
        Fabricate.build(:invite, redemption_count: 2, max_redemptions_allowed: 1, invited_by: user)
      expect(invite).not_to be_valid
      expect(invite.errors.full_messages.first).to include(
        I18n.t("invite.redemption_count_less_than_max", max_redemptions_allowed: 1),
      )
    end
  end

  describe "before_save" do
    it "regenerates the email token when email is changed" do
      invite = Fabricate(:invite, email: "test@example.com")
      token = invite.email_token

      invite.update!(email: "test@example.com")
      expect(invite.email_token).to eq(token)

      invite.update!(email: "test2@example.com")
      expect(invite.email_token).not_to eq(token)

      invite.update!(email: nil)
      expect(invite.email_token).to eq(nil)
    end
  end

  describe ".generate" do
    it "saves an invites" do
      invite = Invite.generate(user, email: "TEST@EXAMPLE.COM")
      expect(invite.invite_key).to be_present
      expect(invite.email).to eq("test@example.com")
    end

    it "can succeed for staged users emails" do
      Fabricate(:staged, email: "test@example.com")
      invite = Invite.generate(user, email: "test@example.com")
      expect(invite.email).to eq("test@example.com")
    end

    it "raises an error when inviting an existing user" do
      expect { Invite.generate(user, email: user.email) }.to raise_error(Invite::UserExists)
    end

    it "escapes the email_address when raising an existing user error" do
      user.email = xss_email
      user.save(validate: false)

      expect { Invite.generate(user, email: user.email) }.to raise_error(
        Invite::UserExists,
        I18n.t("invite.user_exists", email: escaped_email),
      )
    end

    context "with email" do
      it "can be created and a job is enqueued to email the invite" do
        invite = Invite.generate(user, email: "test@example.com")
        expect(invite.email).to eq("test@example.com")
        expect(invite.emailed_status).to eq(Invite.emailed_status_types[:sending])
        expect(invite.email_token).not_to eq(nil)
        expect(Jobs::InviteEmail.jobs.size).to eq(1)
      end

      it "can skip the job to email the invite" do
        invite = Invite.generate(user, email: "test@example.com", skip_email: true)
        expect(invite.emailed_status).to eq(Invite.emailed_status_types[:not_required])
        expect(Jobs::InviteEmail.jobs.size).to eq(0)
      end

      it "can invite the same user after their invite was destroyed" do
        Invite.generate(user, email: "test@example.com").destroy!
        invite = Invite.generate(user, email: "test@example.com")
        expect(invite).to be_present
      end
    end

    context "with link" do
      it "does not enqueue a job to email the invite" do
        invite = Invite.generate(user, skip_email: true)
        expect(invite.emailed_status).to eq(Invite.emailed_status_types[:not_required])
        expect(Jobs::InviteEmail.jobs.size).to eq(0)
      end

      it "can be created" do
        invite = Invite.generate(user, max_redemptions_allowed: 5)
        expect(invite.max_redemptions_allowed).to eq(5)
        expect(invite.expires_at.to_date).to eq(
          SiteSetting.invite_expiry_days.days.from_now.to_date,
        )
        expect(invite.emailed_status).to eq(Invite.emailed_status_types[:not_required])
        expect(invite.is_invite_link?).to eq(true)
        expect(invite.email_token).to eq(nil)
      end

      it "checks for max_redemptions_allowed range" do
        SiteSetting.invite_link_max_redemptions_limit_users = 3
        expect { Invite.generate(user, max_redemptions_allowed: 4) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )

        SiteSetting.invite_link_max_redemptions_limit = 3
        expect { Invite.generate(Fabricate(:admin), max_redemptions_allowed: 4) }.to raise_error(
          ActiveRecord::RecordInvalid,
        )
      end
    end

    context "when sending an invite to the same user" do
      fab!(:invite) { Invite.generate(user, email: "test@example.com") }

      it "returns the original invite" do
        %w[test@EXAMPLE.com TEST@example.com].each do |email|
          expect(Invite.generate(user, email: email)).to eq(invite)
        end
      end

      it "updates timestamp of existing invite" do
        freeze_time
        invite.update!(created_at: 10.days.ago)
        resend_invite = Invite.generate(user, email: "test@example.com")
        expect(resend_invite).to eq(invite)
        expect(resend_invite.created_at).to eq_time(Time.zone.now)
      end

      it "returns a new invite if the other has expired" do
        SiteSetting.invite_expiry_days = 1
        invite.update!(expires_at: 2.days.ago)

        new_invite = Invite.generate(user, email: "test@example.com")
        expect(new_invite).not_to eq(invite)
        expect(new_invite).not_to be_expired
      end

      it "returns a new invite when invited by a different user" do
        invite = Invite.generate(user, email: "test@example.com")
        expect(invite.email).to eq("test@example.com")

        another_invite = Invite.generate(Fabricate(:user), email: "test@example.com")
        expect(another_invite.email).to eq("test@example.com")

        expect(invite.invite_key).not_to eq(another_invite.invite_key)
      end

      context "when email is already invited 3 times" do
        before do
          RateLimiter.enable
          3.times { Invite.generate(user, email: "test@example.com") }
        end

        it "raises an error" do
          expect { Invite.generate(user, email: "test@example.com") }.to raise_error(
            RateLimiter::LimitExceeded,
          )
        end
      end
    end

    context "when inviting to a topic" do
      fab!(:topic)
      let(:invite) { Invite.generate(topic.user, email: "test@example.com", topic: topic) }

      it "belongs to the topic" do
        expect(topic.invites).to contain_exactly(invite)
        expect(invite.topics).to contain_exactly(topic)
      end

      context "when adding to another topic" do
        fab!(:another_topic) { Fabricate(:topic, user: topic.user) }

        it "should be the same invite" do
          new_invite = Invite.generate(topic.user, email: "test@example.com", topic: another_topic)
          expect(invite).to eq(new_invite)
          expect(invite.topics).to contain_exactly(topic, another_topic)
          expect(topic.invites).to contain_exactly(invite)
          expect(another_topic.invites).to contain_exactly(invite)
        end
      end
    end
  end

  describe "#redeem" do
    fab!(:invite)

    it "works" do
      user = invite.redeem
      expect(invite.invited_users.map(&:user)).to contain_exactly(user)
      expect(user.is_a?(User)).to eq(true)
      expect(user.trust_level).to eq(SiteSetting.default_invitee_trust_level)
      expect(user.send_welcome_message).to eq(true)

      expect(invite.reload.redemption_count).to eq(1)
      expect(invite.redeem).to be_blank
    end

    it "keeps custom fields" do
      user_field = Fabricate(:user_field)
      staged_user = Fabricate(:user, staged: true, email: invite.email)
      staged_user.set_user_field(user_field.id, "some value")
      staged_user.save_custom_fields

      expect(invite.redeem).to eq(staged_user)
      expect(staged_user.reload.user_fields[user_field.id.to_s]).to eq("some value")
    end

    it "creates a notification for the invitee" do
      expect { invite.redeem }.to change { Notification.count }
    end

    it "does not work with expired invites" do
      invite.update!(expires_at: 1.day.ago)
      expect(invite.redeem).to be_blank
    end

    it "does not work with deleted invites" do
      invite.trash!
      expect(invite.redeem).to be_blank
    end

    it "does not work with invalidated invites" do
      invite.update!(invalidated_at: 1.day.ago)
      expect(invite.redeem).to be_blank
    end

    it "deletes duplicate invite" do
      another_invite = Fabricate(:invite, email: invite.email, invited_by: Fabricate(:user))
      another_redeemed_invite =
        Fabricate(:invite, email: invite.email, invited_by: Fabricate(:user))
      Fabricate(:invited_user, invite: another_redeemed_invite)

      user = invite.redeem
      expect(user).not_to eq(nil)
      expect(Invite.find_by(id: another_invite.id)).to eq(nil)
      expect(Invite.find_by(id: another_redeemed_invite.id)).not_to eq(nil)
    end

    context "as a moderator" do
      it "will give the user a moderator flag" do
        invite.update!(moderator: true, invited_by: Fabricate(:admin))

        user = invite.redeem
        expect(user).to be_moderator
      end

      it "will not give the user a moderator flag if the inviter is not staff" do
        invite.update!(moderator: true)

        user = invite.redeem
        expect(user).not_to be_moderator
      end
    end

    context "when inviting to groups" do
      fab!(:group)

      before do
        group.add_owner(invite.invited_by)
        invite.invited_groups.create!(group_id: group.id)
      end

      it "add the user to the correct groups" do
        user = invite.redeem
        expect(user.groups).to contain_exactly(group)
      end
      it "should not raise error when both group & site tag preferences same" do
        tag = Fabricate(:tag)
        group.tracking_tags = [tag.name]
        group.save!
        SiteSetting.default_tags_tracking = tag.name

        expect { invite.redeem }.not_to raise_error
      end
    end

    context "when inviting to a topic" do
      fab!(:topic) { Fabricate(:private_message_topic) }
      fab!(:another_topic) { Fabricate(:private_message_topic) }

      before { invite.topic_invites.create!(topic: topic) }

      it "adds the user to topic_users" do
        invited_user = invite.redeem
        expect(invited_user).not_to eq(nil)
        expect(topic.reload.allowed_users.include?(invited_user)).to eq(true)
        expect(Guardian.new(invited_user).can_see?(topic)).to eq(true)
      end
    end
  end

  describe "#redeem_for_existing_user" do
    fab!(:invite) { Fabricate(:invite, email: "test@example.com") }
    fab!(:user) { Fabricate(:user, email: invite.email) }

    it "redeems the invite from email" do
      Invite.redeem_for_existing_user(user)
      expect(invite.reload).to be_redeemed
    end

    it "does not redeem the invite if email does not match" do
      user.update!(email: "test2@example.com")
      Invite.redeem_for_existing_user(user)
      expect(invite.reload).not_to be_redeemed
    end

    it "does not work with expired invites" do
      invite.update!(expires_at: 1.day.ago)
      Invite.redeem_for_existing_user(user)
      expect(invite).not_to be_redeemed
    end

    it "does not work with deleted invites" do
      invite.trash!
      Invite.redeem_for_existing_user(user)
      expect(invite).not_to be_redeemed
    end

    it "does not work with invalidated invites" do
      invite.update!(invalidated_at: 1.day.ago)
      Invite.redeem_for_existing_user(user)
      expect(invite).not_to be_redeemed
    end
  end

  describe "scopes" do
    fab!(:inviter) { Fabricate(:user) }

    fab!(:pending_invite) { Fabricate(:invite, invited_by: inviter, email: "pending@example.com") }
    fab!(:pending_link_invite) do
      Fabricate(:invite, invited_by: inviter, email: nil, max_redemptions_allowed: 5)
    end
    fab!(:pending_invite_from_another_user) { Fabricate(:invite) }

    fab!(:expired_invite) do
      Fabricate(:invite, invited_by: inviter, email: "expired@example.com", expires_at: 1.day.ago)
    end

    fab!(:redeemed_invite) do
      Fabricate(:invite, invited_by: inviter, email: "redeemed@example.com")
    end
    let!(:redeemed_invite_user) { redeemed_invite.redeem }

    fab!(:partially_redeemed_invite) do
      Fabricate(:invite, invited_by: inviter, email: nil, max_redemptions_allowed: 5)
    end
    let!(:partially_redeemed_invite_user) do
      partially_redeemed_invite.redeem(email: "partially_redeemed_invite@example.com")
    end

    fab!(:redeemed_and_expired_invite) do
      Fabricate(:invite, invited_by: inviter, email: "redeemed_and_expired@example.com")
    end
    let!(:redeemed_and_expired_invite_user) do
      user = redeemed_and_expired_invite.redeem
      redeemed_and_expired_invite.update!(expires_at: 1.day.ago)
      user
    end

    fab!(:partially_redeemed_and_expired_invite) do
      Fabricate(:invite, invited_by: inviter, email: nil, max_redemptions_allowed: 5)
    end
    let!(:partially_redeemed_and_expired_invite_user) do
      user =
        partially_redeemed_and_expired_invite.redeem(
          email: "partially_redeemed_and_expired_invite@example.com",
        )
      partially_redeemed_and_expired_invite.update!(expires_at: 1.day.ago)
      user
    end

    describe "#pending" do
      it "returns pending invites only" do
        expect(Invite.pending(inviter)).to contain_exactly(
          pending_invite,
          pending_link_invite,
          partially_redeemed_invite,
        )
      end
    end

    describe "#expired" do
      it "returns expired invites only" do
        expect(Invite.expired(inviter)).to contain_exactly(
          expired_invite,
          partially_redeemed_and_expired_invite,
        )
      end
    end

    describe "#redeemed_users" do
      it "returns redeemed users" do
        expect(Invite.redeemed_users(inviter).map(&:user)).to contain_exactly(
          redeemed_invite_user,
          partially_redeemed_invite_user,
          redeemed_and_expired_invite_user,
          partially_redeemed_and_expired_invite_user,
        )
      end

      it "returns redeemed users for trashed invites" do
        [
          redeemed_invite,
          partially_redeemed_invite,
          redeemed_and_expired_invite,
          partially_redeemed_and_expired_invite,
        ].each(&:trash!)

        expect(Invite.redeemed_users(inviter).map(&:user)).to contain_exactly(
          redeemed_invite_user,
          partially_redeemed_invite_user,
          redeemed_and_expired_invite_user,
          partially_redeemed_and_expired_invite_user,
        )
      end
    end
  end

  describe ".invalidate_for_email" do
    it "returns nil if there is no invite for the given email" do
      invite = Invite.invalidate_for_email("test@example.com")
      expect(invite).to eq(nil)
    end

    it "sets the matching invite to be invalid" do
      invite = Fabricate(:invite, invited_by: Fabricate(:user), email: "test@example.com")
      result = Invite.invalidate_for_email("test@example.com")

      expect(result).to eq(invite)
      expect(result.link_valid?).to eq(false)
    end

    it "sets the matching invite to be invalid without being case-sensitive" do
      invite = Fabricate(:invite, invited_by: Fabricate(:user), email: "test@Example.COM")
      result = Invite.invalidate_for_email("test@EXAMPLE.com")

      expect(result).to eq(invite)
      expect(result.link_valid?).to eq(false)
    end
  end

  describe "#resend_email" do
    fab!(:invite)

    it "resets expiry of a resent invite" do
      invite.update!(invalidated_at: 10.days.ago, expires_at: 10.days.ago)
      expect(invite).to be_expired

      invite.resend_invite
      expect(invite).not_to be_expired
      expect(invite.invalidated_at).to be_nil
    end
  end

  describe "#can_be_redeemed_by?" do
    context "for invite links" do
      fab!(:invite) { Fabricate(:invite, email: nil, domain: nil, max_redemptions_allowed: 1) }

      it "returns false if invite is already redeemed" do
        invite.update!(redemption_count: 1)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if the invite is expired" do
        invite.update!(expires_at: 10.days.ago)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if invite is deleted" do
        invite.trash!
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if invite is invalidated" do
        invite.update!(invalidated_at: 1.day.ago)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if the user already redeemed it" do
        InvitedUser.create(user: user, invite: invite)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if domain does not match user email" do
        invite.update!(domain: "zzzzz.com")
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns true if domain does match user email" do
        invite.update!(domain: "invitetest.com")
        expect(invite.can_be_redeemed_by?(user)).to eq(true)
      end

      it "returns true by default if all other conditions are met and domain and invite are blank" do
        expect(invite.can_be_redeemed_by?(user)).to eq(true)
      end
    end

    context "for email invites" do
      fab!(:invite) do
        invite = Fabricate(:invite, email: "otherexisting@invitetest.com", domain: nil)
        user.update!(email: "otherexisting@invitetest.com")
        invite
      end

      it "returns false if invite is already redeemed" do
        InvitedUser.create(user: Fabricate(:user), invite: invite)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if the invite is expired" do
        invite.update!(expires_at: 10.days.ago)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if invite is deleted" do
        invite.trash!
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if invite is invalidated" do
        invite.update!(invalidated_at: 1.day.ago)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if the user already redeemed it" do
        InvitedUser.create(user: user, invite: invite)
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns false if email does not match user email" do
        invite.update!(email: "blahblah@test.com")
        expect(invite.can_be_redeemed_by?(user)).to eq(false)
      end

      it "returns true if email does match user email" do
        expect(invite.can_be_redeemed_by?(user)).to eq(true)
      end
    end
  end

  describe "#invalidate!" do
    subject(:invalidate) { invite.invalidate! }

    fab!(:invite)

    before { freeze_time }

    it "invalidates the invite" do
      expect { invalidate }.to change { invite.invalidated_at }.to Time.current
    end

    it "returns the invite" do
      expect(invalidate).to eq invite
    end

    context "when the invite is in an invalid state" do
      before { invite.update_attribute(:custom_message, "a" * 2000) }

      it "still invalidates the invite" do
        expect(invite).to be_invalid
        expect { invalidate }.to change { invite.invalidated_at }.to Time.current
      end
    end
  end
end
