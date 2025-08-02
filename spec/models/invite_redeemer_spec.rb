# frozen_string_literal: true

RSpec.describe InviteRedeemer do
  fab!(:admin)

  describe "#initialize" do
    fab!(:redeeming_user) { Fabricate(:user, email: "redeemer@test.com") }

    context "for invite link" do
      fab!(:invite) { Fabricate(:invite, email: nil) }

      context "when an email is passed in without a redeeming user" do
        it "uses that email for invite redemption" do
          redeemer = described_class.new(invite: invite, email: "blah@test.com")
          expect(redeemer.email).to eq("blah@test.com")
          expect { redeemer.redeem }.to change { User.count }
          expect(User.find_by_email(redeemer.email)).to be_present
        end
      end

      context "when an email is passed in with a redeeming user" do
        it "uses the redeeming user's email for invite redemption" do
          redeemer =
            described_class.new(
              invite: invite,
              email: "blah@test.com",
              redeeming_user: redeeming_user,
            )
          expect(redeemer.email).to eq(redeeming_user.email)
          expect { redeemer.redeem }.not_to change { User.count }
        end
      end

      context "when an email is not passed in with a redeeming user" do
        it "uses the redeeming user's email for invite redemption" do
          redeemer = described_class.new(invite: invite, email: nil, redeeming_user: redeeming_user)
          expect(redeemer.email).to eq(redeeming_user.email)
          expect { redeemer.redeem }.not_to change { User.count }
        end
      end

      context "when no email and no redeeming user is passed in" do
        it "raises an error" do
          expect {
            described_class.new(invite: invite, email: nil, redeeming_user: nil)
          }.to raise_error(Discourse::InvalidParameters)
        end
      end
    end

    context "for invite with email" do
      fab!(:invite) { Fabricate(:invite, email: "foobar@example.com") }

      context "when an email is passed in without a redeeming user" do
        it "uses that email for invite redemption" do
          redeemer = described_class.new(invite: invite, email: "foobar@example.com")
          expect(redeemer.email).to eq("foobar@example.com")
          expect { redeemer.redeem }.to change { User.count }
          expect(User.find_by_email(redeemer.email)).to be_present
        end
      end

      context "when an email is passed in with a redeeming user" do
        it "uses the redeeming user's email for invite redemption" do
          redeemer =
            described_class.new(
              invite: invite,
              email: "blah@test.com",
              redeeming_user: redeeming_user,
            )
          expect(redeemer.email).to eq(redeeming_user.email)
          expect { redeemer.redeem }.to raise_error(
            ActiveRecord::RecordNotSaved,
            I18n.t("invite.not_matching_email"),
          )
        end
      end

      context "when an email is not passed in with a redeeming user" do
        it "uses the invite email for invite redemption" do
          redeemer = described_class.new(invite: invite, email: nil, redeeming_user: redeeming_user)
          expect(redeemer.email).to eq("foobar@example.com")
          expect { redeemer.redeem }.to raise_error(
            ActiveRecord::RecordNotSaved,
            I18n.t("invite.not_matching_email"),
          )
        end
      end

      context "when no email and no redeeming user is passed in" do
        it "uses the invite email for invite redemption" do
          redeemer = described_class.new(invite: invite, email: nil, redeeming_user: nil)
          expect(redeemer.email).to eq("foobar@example.com")
          expect { redeemer.redeem }.to change { User.count }
          expect(User.find_by_email(redeemer.email)).to be_present
        end
      end
    end
  end

  describe ".create_user_from_invite" do
    it "should be created correctly" do
      invite = Fabricate(:invite, email: "walter.white@email.com")
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
        )
      expect(user.username).to eq("walter")
      expect(user.name).to eq("Walter White")
      expect(user.email).to eq("walter.white@email.com")
      expect(user.approved).to eq(false)
      expect(user.active).to eq(false)
    end

    it "can set the password and ip_address" do
      password = "s3cure5tpasSw0rD"
      ip_address = "192.168.1.1"
      invite = Fabricate(:invite, email: "walter.white@email.com")
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
          password: password,
          ip_address: ip_address,
        )
      expect(user).to have_password
      expect(user.confirm_password?(password)).to eq(true)
      expect(user.approved).to eq(false)
      expect(user.ip_address).to eq(ip_address)
      expect(user.registration_ip_address).to eq(ip_address)
    end

    it "raises exception with record and errors" do
      error = nil
      invite = Fabricate(:invite, email: "walter.white@email.com")
      begin
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
          password: "aaa",
        )
      rescue ActiveRecord::RecordInvalid => e
        error = e
      end
      expect(error).to be_present
      expect(error.record.errors.errors[0].attribute).to eq :"user_password.password"
    end

    it "should unstage user" do
      staged_user =
        Fabricate(
          :staged,
          email: "staged@account.com",
          active: true,
          username: "staged1",
          name: "Stage Name",
        )
      invite = Fabricate(:invite, email: "staged@account.com")
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
        )

      expect(user.id).to eq(staged_user.id)
      expect(user.username).to eq("walter")
      expect(user.name).to eq("Walter White")
      expect(user.staged).to eq(false)
      expect(user.email).to eq("staged@account.com")
      expect(user.approved).to eq(false)
    end

    it "activates user invited via email with a token" do
      invite =
        Fabricate(
          :invite,
          invited_by: Fabricate(:admin),
          email: "walter.white@email.com",
          emailed_status: Invite.emailed_status_types[:sent],
        )
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
          email_token: invite.email_token,
        )

      expect(user.username).to eq("walter")
      expect(user.name).to eq("Walter White")
      expect(user.email).to eq("walter.white@email.com")
      expect(user.approved).to eq(false)
      expect(user.active).to eq(true)
    end

    it "does not activate user invited via email with a wrong token" do
      invite =
        Fabricate(
          :invite,
          invited_by: Fabricate(:user),
          email: "walter.white@email.com",
          emailed_status: Invite.emailed_status_types[:sent],
        )
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
          email_token: "wrong_token",
        )
      expect(user.active).to eq(false)
    end

    it "does not activate user invited via email without a token" do
      invite =
        Fabricate(
          :invite,
          invited_by: Fabricate(:user),
          email: "walter.white@email.com",
          emailed_status: Invite.emailed_status_types[:sent],
        )
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
        )
      expect(user.active).to eq(false)
    end

    it "does not activate user invited via links" do
      invite =
        Fabricate(
          :invite,
          email: "walter.white@email.com",
          emailed_status: Invite.emailed_status_types[:not_required],
        )
      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          username: "walter",
          name: "Walter White",
        )

      expect(user.username).to eq("walter")
      expect(user.name).to eq("Walter White")
      expect(user.email).to eq("walter.white@email.com")
      expect(user.approved).to eq(false)
      expect(user.active).to eq(false)
    end

    it "approves and actives user when redeeming an invite with email token and SiteSetting.invite_only is enabled" do
      SiteSetting.invite_only = true
      Jobs.run_immediately!

      invite =
        Fabricate(
          :invite,
          invited_by: admin,
          email: "walter.white@email.com",
          emailed_status: Invite.emailed_status_types[:sent],
        )

      user =
        InviteRedeemer.create_user_from_invite(
          invite: invite,
          email: invite.email,
          email_token: invite.email_token,
          username: "walter",
          name: "Walter White",
        )

      expect(user.name).to eq("Walter White")
      expect(user.username).to eq("walter")
      expect(user.email).to eq("walter.white@email.com")
      expect(user.approved).to eq(true)
      expect(user.active).to eq(true)
      expect(ReviewableUser.count).to eq(0)
    end
  end

  describe "#redeem" do
    let(:name) { "john snow" }
    let(:username) { "kingofthenorth" }
    let(:password) { "know5nOthiNG" }
    let(:invite_redeemer) do
      InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name)
    end

    context "with email" do
      fab!(:invite) { Fabricate(:invite, email: "foobar@example.com") }
      context "when must_approve_users setting is enabled" do
        before { SiteSetting.must_approve_users = true }

        it "should redeem an invite but not approve the user when invite is created by a staff user" do
          inviter = invite.invited_by
          inviter.update!(admin: true)
          user = invite_redeemer.redeem

          expect(user.name).to eq(name)
          expect(user.username).to eq(username)
          expect(user.invited_by).to eq(inviter)
          expect(user.approved).to eq(false)

          expect(inviter.notifications.count).to eq(1)
        end

        it "should redeem the invite but not approve the user when invite is created by a regular user" do
          inviter = invite.invited_by
          user = invite_redeemer.redeem

          expect(user.name).to eq(name)
          expect(user.username).to eq(username)
          expect(user.invited_by).to eq(inviter)
          expect(user.approved).to eq(false)

          expect(inviter.notifications.count).to eq(1)
        end

        it "should redeem the invite and approve the user when user email is in auto_approve_email_domains setting" do
          SiteSetting.auto_approve_email_domains = "example.com"
          user = invite_redeemer.redeem

          expect(user.name).to eq(name)
          expect(user.username).to eq(username)
          expect(user.approved).to eq(true)
          expect(user.approved_by).to eq(Discourse.system_user)
        end
      end

      it "should redeem the invite if invited by non staff and approve if staff not required to approve" do
        inviter = invite.invited_by
        user = invite_redeemer.redeem

        expect(user.name).to eq(name)
        expect(user.username).to eq(username)
        expect(user.invited_by).to eq(inviter)
        expect(inviter.notifications.count).to eq(1)
        expect(user.approved).to eq(false)
      end

      it "should delete invite if invited_by user has been removed" do
        invite.invited_by.destroy!
        expect { invite.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it "can set password" do
        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
          ).redeem
        expect(user).to have_password
        expect(user.confirm_password?(password)).to eq(true)
        expect(user.approved).to eq(false)
      end

      it "can set custom fields" do
        required_field = Fabricate(:user_field)
        optional_field = Fabricate(:user_field, required: false)
        user_fields = { required_field.id.to_s => "value1", optional_field.id.to_s => "value2" }
        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
            user_custom_fields: user_fields,
          ).redeem

        expect(user).to be_present
        expect(user.custom_fields["user_field_#{required_field.id}"]).to eq("value1")
        expect(user.custom_fields["user_field_#{optional_field.id}"]).to eq("value2")
      end

      it "can set custom fields with field_type confirm properly" do
        optional_field_1 = Fabricate(:user_field, field_type: "confirm", required: false)
        optional_field_2 = Fabricate(:user_field, field_type: "confirm", required: false)
        optional_field_3 = Fabricate(:user_field, field_type: "confirm", required: false)
        user_fields = {
          optional_field_1.id.to_s => "false",
          optional_field_2.id.to_s => "true",
          optional_field_3.id.to_s => "",
        }

        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
            user_custom_fields: user_fields,
          ).redeem

        expect(user).to be_present
        expect(user.custom_fields["user_field_#{optional_field_1.id}"]).to eq(nil)
        expect(user.custom_fields["user_field_#{optional_field_2.id}"]).to eq("true")
        expect(user.custom_fields["user_field_#{optional_field_3.id}"]).to eq(nil)
      end

      it "does not add user to group if inviter does not have permissions" do
        group = Fabricate(:group, grant_trust_level: 2)
        InvitedGroup.create(group_id: group.id, invite_id: invite.id)
        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
          ).redeem

        expect(user.group_users.count).to eq(0)
      end

      it "adds user to group" do
        group = Fabricate(:group, grant_trust_level: 2)
        InvitedGroup.create(group_id: group.id, invite_id: invite.id)
        group.add_owner(invite.invited_by)

        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
          ).redeem

        expect(user.group_users.count).to eq(4)
        expect(user.trust_level).to eq(2)
      end

      it "adds an entry to the group logs when the invited user is added to a group" do
        group = Fabricate(:group)
        InvitedGroup.create(group_id: group.id, invite_id: invite.id)
        group.add_owner(invite.invited_by)

        GroupHistory.destroy_all

        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
          ).redeem

        expect(group.reload.usernames.split(",")).to include(user.username)
        expect(
          GroupHistory.exists?(
            target_user_id: user.id,
            acting_user: invite.invited_by.id,
            group_id: group.id,
            action: GroupHistory.actions[:add_user_to_group],
          ),
        ).to eq(true)
      end

      it "only allows one user to be created per invite" do
        user = invite_redeemer.redeem
        invite.reload

        user.email = "john@example.com"
        user.save!

        another_invite_redeemer =
          InviteRedeemer.new(invite: invite, email: invite.email, username: username, name: name)
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

      it "raises an error if the email does not match the invite email" do
        redeemer =
          InviteRedeemer.new(invite: invite, email: "blah@test.com", username: username, name: name)
        expect { redeemer.redeem }.to raise_error(
          ActiveRecord::RecordNotSaved,
          I18n.t("invite.not_matching_email"),
        )
      end

      it "adds the user to the appropriate private topic and no others" do
        topic1 = Fabricate(:private_message_topic)
        topic2 = Fabricate(:private_message_topic)
        TopicInvite.create(invite: invite, topic: topic1)
        user =
          InviteRedeemer.new(
            invite: invite,
            email: invite.email,
            username: username,
            name: name,
            password: password,
          ).redeem
        expect(TopicAllowedUser.exists?(topic: topic1, user: user)).to eq(true)
        expect(TopicAllowedUser.exists?(topic: topic2, user: user)).to eq(false)
      end

      context "when a redeeming user is passed in" do
        fab!(:redeeming_user) { Fabricate(:user, email: "foobar@example.com") }

        it "raises an error if the email does not match the invite email" do
          redeeming_user.update!(email: "foo@bar.com")
          redeemer = InviteRedeemer.new(invite: invite, redeeming_user: redeeming_user)
          expect { redeemer.redeem }.to raise_error(
            ActiveRecord::RecordNotSaved,
            I18n.t("invite.not_matching_email"),
          )
        end

        it "adds the user to the appropriate private topic and no others" do
          topic1 = Fabricate(:private_message_topic)
          topic2 = Fabricate(:private_message_topic)
          TopicInvite.create(invite: invite, topic: topic1)
          InviteRedeemer.new(invite: invite, redeeming_user: redeeming_user).redeem
          expect(TopicAllowedUser.exists?(topic: topic1, user: redeeming_user)).to eq(true)
          expect(TopicAllowedUser.exists?(topic: topic2, user: redeeming_user)).to eq(false)
        end

        it "does not create a topic allowed user record if the invited user is already in the topic" do
          topic1 = Fabricate(:private_message_topic)
          TopicInvite.create(invite: invite, topic: topic1)
          TopicAllowedUser.create(topic: topic1, user: redeeming_user)
          expect {
            InviteRedeemer.new(invite: invite, redeeming_user: redeeming_user).redeem
          }.not_to change { TopicAllowedUser.count }
        end
      end
    end

    context "with domain" do
      fab!(:invite) { Fabricate(:invite, email: nil, domain: "test.com") }

      it "raises an error if the email domain does not match the invite domain" do
        redeemer =
          InviteRedeemer.new(
            invite: invite,
            email: "blah@somesite.com",
            username: username,
            name: name,
          )
        expect { redeemer.redeem }.to raise_error(
          ActiveRecord::RecordNotSaved,
          I18n.t("invite.domain_not_allowed"),
        )
      end

      context "when a redeeming user is passed in" do
        fab!(:redeeming_user) { Fabricate(:user, email: "foo@test.com") }

        it "raises an error if the user's email domain does not match the invite domain" do
          redeeming_user.update!(email: "foo@bar.com")
          redeemer = InviteRedeemer.new(invite: invite, redeeming_user: redeeming_user)
          expect { redeemer.redeem }.to raise_error(
            ActiveRecord::RecordNotSaved,
            I18n.t("invite.domain_not_allowed"),
          )
        end
      end
    end

    context "with invite_link" do
      fab!(:invite_link) do
        Fabricate(
          :invite,
          email: nil,
          max_redemptions_allowed: 5,
          expires_at: 1.month.from_now,
          emailed_status: Invite.emailed_status_types[:not_required],
        )
      end
      let(:invite_redeemer) { InviteRedeemer.new(invite: invite_link, email: "foo@example.com") }

      it "works as expected" do
        user = invite_redeemer.redeem
        invite_link.reload

        expect(user.send_welcome_message).to eq(true)
        expect(user.trust_level).to eq(SiteSetting.default_invitee_trust_level)
        expect(user.active).to eq(false)
        expect(invite_link.redemption_count).to eq(1)
      end

      it "raises an error if email has already been invited" do
        invite_redeemer.redeem
        invite_link.reload

        another_invite_redeemer = InviteRedeemer.new(invite: invite_link, email: "foo@example.com")
        expect { another_invite_redeemer.redeem }.to raise_error(
          Invite::UserExists,
          I18n.t("invite.existing_user_already_redemeed"),
        )
      end

      it "should redeem the invite if InvitedUser record does not exists for email" do
        invite_redeemer.redeem
        invite_link.reload

        another_invite_redeemer = InviteRedeemer.new(invite: invite_link, email: "bar@example.com")
        another_user = another_invite_redeemer.redeem
        expect(another_user.is_a?(User)).to eq(true)
      end

      it "raises an error if the email is already being used by an existing user" do
        Fabricate(:user, email: "foo@example.com")
        expect { invite_redeemer.redeem }.to raise_error(
          ActiveRecord::RecordInvalid,
          /Primary email has already been taken/,
        )
      end

      context "when a redeeming user is passed in" do
        fab!(:redeeming_user) { Fabricate(:user, email: "foo@example.com") }

        it "does not create a new user" do
          expect do
            InviteRedeemer.new(invite: invite_link, redeeming_user: redeeming_user).redeem
          end.not_to change { User.count }
        end

        it "does not set the redeeming user's invited_by since the user is already present" do
          redeeming_user.update(created_at: Time.now - 6.seconds)
          group = Fabricate(:group)
          group.add_owner(invite_link.invited_by)
          InvitedGroup.create(group_id: group.id, invite_id: invite_link.id)

          expect do
            InviteRedeemer.new(invite: invite_link, redeeming_user: redeeming_user).redeem
          end.not_to change { redeeming_user.invited_by }
        end
      end
    end
  end
end
