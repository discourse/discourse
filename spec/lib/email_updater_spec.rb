# frozen_string_literal: true

RSpec.describe EmailUpdater do
  let(:old_email) { "old.email@example.com" }
  let(:new_email) { "new.email@example.com" }

  it "provides better error message when a staged user has the same email" do
    SiteSetting.hide_email_address_taken = false

    Fabricate(:user, staged: true, email: new_email)

    user = Fabricate(:user, email: old_email)
    updater = EmailUpdater.new(guardian: user.guardian, user: user)
    updater.change_to(new_email)

    expect(updater.errors).to be_present
    expect(updater.errors.messages[:base].first).to be I18n.t("change_email.error_staged")
  end

  it "does not create multiple email change requests" do
    user = Fabricate(:user)

    EmailUpdater.new(guardian: Fabricate(:admin).guardian, user: user).change_to(new_email)
    EmailUpdater.new(guardian: Fabricate(:admin).guardian, user: user).change_to(new_email)

    expect(user.email_change_requests.count).to eq(1)
  end

  context "when an admin is changing the email of another user" do
    let(:admin) { Fabricate(:admin) }
    let(:updater) { EmailUpdater.new(guardian: admin.guardian, user: user) }

    def expect_old_email_job
      expect_enqueued_with(
        job: :critical_user_email,
        args: {
          to_address: old_email,
          type: :notify_old_email,
          user_id: user.id,
        },
      ) { yield }
    end

    context "for a regular user" do
      let(:user) { Fabricate(:user, email: old_email) }

      it "sends an email to the user for them to confirm the email change" do
        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_new_email,
            to_address: new_email,
          },
        ) { updater.change_to(new_email) }
      end

      it "sends an email to confirm old email first if require_change_email_confirmation is enabled" do
        SiteSetting.require_change_email_confirmation = true

        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_old_email,
            to_address: old_email,
          },
        ) { updater.change_to(new_email) }

        expect(updater.change_req).to be_present
        expect(updater.change_req.old_email).to eq(old_email)
        expect(updater.change_req.new_email).to eq(new_email)
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])
        expect(updater.change_req.old_email_token.email).to eq(old_email)
        expect(updater.change_req.new_email_token).to be_blank
      end

      it "logs the admin user as the requester" do
        updater.change_to(new_email)
        expect(updater.change_req.requested_by).to eq(admin)
      end

      it "starts the new confirmation process" do
        updater.change_to(new_email)
        expect(updater.errors).to be_blank

        expect(updater.change_req).to be_present
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])

        expect(updater.change_req.old_email).to eq(old_email)
        expect(updater.change_req.new_email).to eq(new_email)
        expect(updater.change_req.old_email_token).to be_blank
        expect(updater.change_req.new_email_token.email).to eq(new_email)
      end
    end

    context "for a staff user" do
      let(:user) { Fabricate(:moderator, email: old_email) }

      before do
        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_old_email,
            to_address: old_email,
          },
        ) { updater.change_to(new_email) }
      end

      it "starts the old confirmation process" do
        expect(updater.errors).to be_blank

        expect(updater.change_req.old_email).to eq(old_email)
        expect(updater.change_req.new_email).to eq(new_email)
        expect(updater.change_req).to be_present
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

        expect(updater.change_req.old_email_token.email).to eq(old_email)
        expect(updater.change_req.new_email_token).to be_blank
      end

      it "does not immediately confirm the request" do
        expect(updater.change_req.change_state).not_to eq(EmailChangeRequest.states[:complete])
      end
    end

    context "when changing their own email" do
      let(:user) { admin }

      before do
        admin.update(email: old_email)

        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_old_email,
            to_address: old_email,
          },
        ) { updater.change_to(new_email) }
      end

      it "logs the user as the requester" do
        updater.change_to(new_email)
        expect(updater.change_req.requested_by).to eq(user)
      end

      it "starts the old confirmation process" do
        expect(updater.errors).to be_blank

        expect(updater.change_req.old_email).to eq(old_email)
        expect(updater.change_req.new_email).to eq(new_email)
        expect(updater.change_req).to be_present
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

        expect(updater.change_req.old_email_token.email).to eq(old_email)
        expect(updater.change_req.new_email_token).to be_blank
      end

      it "does not immediately confirm the request" do
        expect(updater.change_req.change_state).not_to eq(EmailChangeRequest.states[:complete])
      end
    end
  end

  context "as a regular user" do
    let(:user) { Fabricate(:user, email: old_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    context "when changing primary email" do
      before do
        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_new_email,
            to_address: new_email,
          },
        ) { updater.change_to(new_email) }
      end

      it "starts the new confirmation process" do
        expect(updater.errors).to be_blank

        expect(updater.change_req).to be_present
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])

        expect(updater.change_req.old_email).to eq(old_email)
        expect(updater.change_req.new_email).to eq(new_email)
        expect(updater.change_req.old_email_token).to be_blank
        expect(updater.change_req.new_email_token.email).to eq(new_email)
      end

      context "when confirming an invalid token" do
        it "produces an error" do
          updater.confirm("random")
          expect(updater.errors).to be_present
          expect(user.reload.email).not_to eq(new_email)
        end
      end

      context "when confirming a valid token" do
        it "updates the user's email" do
          event =
            DiscourseEvent
              .track_events do
                expect_enqueued_with(
                  job: :critical_user_email,
                  args: {
                    type: :notify_old_email,
                    to_address: old_email,
                  },
                ) { updater.confirm(updater.change_req.new_email_token.token) }
              end
              .last

          expect(updater.errors).to be_blank
          expect(user.reload.email).to eq(new_email)

          expect(event[:event_name]).to eq(:user_updated)
          expect(event[:params].first).to eq(user)

          updater.change_req.reload
          expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end
    end

    context "when adding an email" do
      before do
        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_new_email,
            to_address: new_email,
          },
        ) { updater.change_to(new_email, add: true) }
      end

      context "when confirming a valid token" do
        it "adds a user email" do
          expect(
            UserHistory.where(
              action: UserHistory.actions[:add_email],
              acting_user_id: user.id,
            ).last,
          ).to be_present

          event =
            DiscourseEvent
              .track_events do
                expect_enqueued_with(
                  job: :critical_user_email,
                  args: {
                    type: :notify_old_email_add,
                    to_address: old_email,
                  },
                ) { updater.confirm(updater.change_req.new_email_token.token) }
              end
              .last

          expect(updater.errors).to be_blank
          expect(UserEmail.where(user_id: user.id).pluck(:email)).to contain_exactly(
            user.email,
            new_email,
          )

          expect(event[:event_name]).to eq(:user_updated)
          expect(event[:params].first).to eq(user)

          updater.change_req.reload
          expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end

      context "when it was deleted before" do
        it "works" do
          expect_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :notify_old_email_add,
              to_address: old_email,
            },
          ) { updater.confirm(updater.change_req.new_email_token.token) }

          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email, new_email)

          user.user_emails.where(email: new_email).delete_all
          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email)

          expect_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :confirm_new_email,
              to_address: new_email,
            },
          ) { updater.change_to(new_email, add: true) }

          expect_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :notify_old_email_add,
              to_address: old_email,
            },
          ) { updater.confirm(updater.change_req.new_email_token.token) }

          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email, new_email)
        end
      end
    end

    context "with max_allowed_secondary_emails" do
      let(:secondary_email_1) { "secondary_1@email.com" }
      let(:secondary_email_2) { "secondary_2@email.com" }

      before do
        SiteSetting.max_allowed_secondary_emails = 2
        Fabricate(:secondary_email, user: user, primary: false, email: secondary_email_1)
        Fabricate(:secondary_email, user: user, primary: false, email: secondary_email_2)
      end

      it "max secondary_emails limit reached" do
        updater.change_to(new_email, add: true)
        expect(updater.errors).to be_present
        expect(updater.errors.messages[:base].first).to be I18n.t(
             "change_email.max_secondary_emails_error",
           )
      end
    end
  end

  context "as a staff user" do
    let(:user) { Fabricate(:moderator, email: old_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    before do
      expect_enqueued_with(
        job: :critical_user_email,
        args: {
          type: :confirm_old_email,
          to_address: old_email,
        },
      ) { updater.change_to(new_email) }
    end

    it "starts the old confirmation process" do
      expect(updater.errors).to be_blank

      expect(updater.change_req.old_email).to eq(old_email)
      expect(updater.change_req.new_email).to eq(new_email)
      expect(updater.change_req).to be_present
      expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

      expect(updater.change_req.old_email_token.email).to eq(old_email)
      expect(updater.change_req.new_email_token).to be_blank
    end

    context "when confirming an invalid token" do
      it "produces an error" do
        updater.confirm("random")
        expect(updater.errors).to be_present
        expect(user.reload.email).not_to eq(new_email)
      end
    end

    context "when confirming a valid token" do
      before do
        expect_enqueued_with(
          job: :critical_user_email,
          args: {
            type: :confirm_new_email,
            to_address: new_email,
          },
        ) do
          @old_token = updater.change_req.old_email_token.token
          updater.confirm(@old_token)
        end
      end

      it "starts the new update process" do
        expect(updater.errors).to be_blank
        expect(user.reload.email).to eq(old_email)

        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])
        expect(updater.change_req.new_email_token).to be_present
      end

      it "cannot be confirmed twice" do
        updater.confirm(@old_token)
        expect(updater.errors).to be_present
        expect(user.reload.email).to eq(old_email)

        updater.change_req.reload
        expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])
        expect(updater.change_req.new_email_token.email).to eq(new_email)
      end

      context "when completing the new update process" do
        before do
          expect_not_enqueued_with(
            job: :critical_user_email,
            args: {
              type: :notify_old_email,
              to_address: old_email,
            },
          ) { updater.confirm(updater.change_req.new_email_token.token) }
        end

        it "updates the user's email" do
          expect(updater.errors).to be_blank
          expect(user.reload.email).to eq(new_email)

          updater.change_req.reload
          expect(updater.change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end
    end
  end

  context "when hide_email_address_taken is enabled" do
    before { SiteSetting.hide_email_address_taken = true }

    let(:user) { Fabricate(:user, email: old_email) }
    let(:existing) { Fabricate(:user, email: new_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    it "doesn't error if user exists with new email" do
      updater.change_to(existing.email)
      expect(updater.errors).to be_blank
      expect(user.email_change_requests).to be_empty
    end

    it "sends an email to the owner of the account with the new email" do
      expect_enqueued_with(
        job: :critical_user_email,
        args: {
          type: :account_exists,
          user_id: existing.id,
        },
      ) { updater.change_to(existing.email) }
    end
  end
end
