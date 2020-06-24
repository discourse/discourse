# frozen_string_literal: true

require 'rails_helper'

describe EmailUpdater do
  let(:old_email) { 'old.email@example.com' }
  let(:new_email) { 'new.email@example.com' }

  it "provides better error message when a staged user has the same email" do
    Fabricate(:user, staged: true, email: new_email)

    user = Fabricate(:user, email: old_email)
    updater = EmailUpdater.new(guardian: user.guardian, user: user)
    updater.change_to(new_email)

    expect(updater.errors).to be_present
    expect(updater.errors.messages[:base].first).to be I18n.t("change_email.error_staged")
  end

  context "when an admin is changing the email of another user" do
    let(:admin) { Fabricate(:admin) }
    let(:updater) { EmailUpdater.new(guardian: admin.guardian, user: user) }

    def expect_old_email_job
      Jobs.expects(:enqueue).with(:critical_user_email, has_entries(to_address: old_email, type: :notify_old_email, user_id: user.id))
    end

    def expect_forgot_password_job
      Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :forgot_password, user_id: user.id))
    end

    context "for a regular user" do
      let(:user) { Fabricate(:user, email: old_email) }

      it "does not send an email to the user for them to confirm their new email but still sends the notification to the old email" do
        Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :confirm_new_email, to_address: new_email)).never
        expect_old_email_job
        expect_forgot_password_job
        updater.change_to(new_email)
      end

      it "creates a change request authorizing the new email and immediately confirms it " do
        updater.change_to(new_email)
        change_req = user.email_change_requests.first
        expect(user.reload.email).to eq(new_email)
      end

      it "sends a reset password email to the user so they can set a password for their new email" do
        expect_old_email_job
        expect_forgot_password_job
        updater.change_to(new_email)
      end
    end

    context "for a staff user" do
      let(:user) { Fabricate(:moderator, email: old_email) }

      before do
        Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_old_email, to_address: old_email))
        updater.change_to(new_email)
        @change_req = user.email_change_requests.first
      end

      it "starts the old confirmation process" do
        expect(updater.errors).to be_blank

        expect(@change_req.old_email).to eq(old_email)
        expect(@change_req.new_email).to eq(new_email)
        expect(@change_req).to be_present
        expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

        expect(@change_req.old_email_token.email).to eq(old_email)
        expect(@change_req.new_email_token).to be_blank
      end

      it "does not immediately confirm the request" do
        expect(@change_req.change_state).not_to eq(EmailChangeRequest.states[:complete])
      end
    end

    context "when changing their own email" do
      let(:user) { admin }

      before do
        admin.update(email: old_email)
        Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_old_email, to_address: old_email))
        updater.change_to(new_email)
        @change_req = user.email_change_requests.first
      end

      it "starts the old confirmation process" do
        expect(updater.errors).to be_blank

        expect(@change_req.old_email).to eq(old_email)
        expect(@change_req.new_email).to eq(new_email)
        expect(@change_req).to be_present
        expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

        expect(@change_req.old_email_token.email).to eq(old_email)
        expect(@change_req.new_email_token).to be_blank
      end

      it "does not immediately confirm the request" do
        expect(@change_req.change_state).not_to eq(EmailChangeRequest.states[:complete])
      end
    end
  end

  context 'as a regular user' do
    let(:user) { Fabricate(:user, email: old_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    context "changing primary email" do
      before do
        Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_new_email, to_address: new_email))
        updater.change_to(new_email)
        @change_req = user.email_change_requests.first
      end

      it "starts the new confirmation process" do
        expect(updater.errors).to be_blank

        expect(@change_req).to be_present
        expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])

        expect(@change_req.old_email).to eq(old_email)
        expect(@change_req.new_email).to eq(new_email)
        expect(@change_req.old_email_token).to be_blank
        expect(@change_req.new_email_token.email).to eq(new_email)
      end

      context 'confirming an invalid token' do
        it "produces an error" do
          updater.confirm('random')
          expect(updater.errors).to be_present
          expect(user.reload.email).not_to eq(new_email)
        end
      end

      context 'confirming a valid token' do
        it "updates the user's email" do
          Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :notify_old_email, to_address: old_email))
          updater.confirm(@change_req.new_email_token.token)
          expect(updater.errors).to be_blank
          expect(user.reload.email).to eq(new_email)

          @change_req.reload
          expect(@change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end
    end

    context "adding an email" do
      before do
        Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_new_email, to_address: new_email))
        updater.change_to(new_email, add: true)
        @change_req = user.email_change_requests.first
      end

      context 'confirming a valid token' do
        it "adds a user email" do
          expect(UserHistory.where(action: UserHistory.actions[:add_email], acting_user_id: user.id).last).to be_present

          Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :notify_old_email_add, to_address: old_email))
          updater.confirm(@change_req.new_email_token.token)
          expect(updater.errors).to be_blank
          expect(UserEmail.where(user_id: user.id).pluck(:email)).to contain_exactly(user.email, new_email)

          @change_req.reload
          expect(@change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end

      context 'that was deleted before' do
        it 'works' do
          Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :notify_old_email_add, to_address: old_email))
          updater.confirm(@change_req.new_email_token.token)
          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email, new_email)

          user.user_emails.where(email: new_email).delete_all
          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email)

          Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_new_email, to_address: new_email))
          updater.change_to(new_email, add: true)
          @change_req = user.email_change_requests.first

          Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :notify_old_email_add, to_address: old_email))
          updater.confirm(@change_req.new_email_token.token)
          expect(user.reload.user_emails.pluck(:email)).to contain_exactly(old_email, new_email)
        end
      end
    end
  end

  context 'as a staff user' do
    let(:user) { Fabricate(:moderator, email: old_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    before do
      Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_old_email, to_address: old_email))
      updater.change_to(new_email)
      @change_req = user.email_change_requests.first
    end

    it "starts the old confirmation process" do
      expect(updater.errors).to be_blank

      expect(@change_req.old_email).to eq(old_email)
      expect(@change_req.new_email).to eq(new_email)
      expect(@change_req).to be_present
      expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_old])

      expect(@change_req.old_email_token.email).to eq(old_email)
      expect(@change_req.new_email_token).to be_blank
    end

    context 'confirming an invalid token' do
      it "produces an error" do
        updater.confirm('random')
        expect(updater.errors).to be_present
        expect(user.reload.email).not_to eq(new_email)
      end
    end

    context 'confirming a valid token' do
      before do
        Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :confirm_new_email, to_address: new_email))
        updater.confirm(@change_req.old_email_token.token)
        @change_req.reload
      end

      it "starts the new update process" do
        expect(updater.errors).to be_blank
        expect(user.reload.email).to eq(old_email)

        expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])
        expect(@change_req.new_email_token).to be_present
      end

      it "cannot be confirmed twice" do
        updater.confirm(@change_req.old_email_token.token)
        expect(updater.errors).to be_present
        expect(user.reload.email).to eq(old_email)

        @change_req.reload
        expect(@change_req.change_state).to eq(EmailChangeRequest.states[:authorizing_new])
        expect(@change_req.new_email_token.email).to eq(new_email)
      end

      context "completing the new update process" do
        before do
          Jobs.expects(:enqueue).with(:critical_user_email, has_entries(type: :notify_old_email, to_address: old_email)).never
          updater.confirm(@change_req.new_email_token.token)
        end

        it "updates the user's email" do
          expect(updater.errors).to be_blank
          expect(user.reload.email).to eq(new_email)

          @change_req.reload
          expect(@change_req.change_state).to eq(EmailChangeRequest.states[:complete])
        end
      end
    end
  end

  context 'hide_email_address_taken is enabled' do
    before do
      SiteSetting.hide_email_address_taken = true
    end

    let(:user) { Fabricate(:user, email: old_email) }
    let(:existing) { Fabricate(:user, email: new_email) }
    let(:updater) { EmailUpdater.new(guardian: user.guardian, user: user) }

    it "doesn't error if user exists with new email" do
      updater.change_to(existing.email)
      expect(updater.errors).to be_blank
      expect(user.email_change_requests).to be_empty
    end

    it 'sends an email to the owner of the account with the new email' do
      Jobs.expects(:enqueue).once.with(:critical_user_email, has_entries(type: :account_exists, user_id: existing.id))
      updater.change_to(existing.email)
    end
  end
end
