require 'rails_helper'
require_dependency 'email_updater'

describe EmailUpdater do
  let(:old_email) { 'old.email@example.com' }
  let(:new_email) { 'new.email@example.com' }

  it "provides better error message when a staged user has the same email" do
    Fabricate(:user, staged: true, email: new_email)

    user = Fabricate(:user, email: old_email)
    updater = EmailUpdater.new(user.guardian, user)
    updater.change_to(new_email)

    expect(updater.errors).to be_present
    expect(updater.errors.messages[:base].first).to be I18n.t("change_email.error_staged")
  end

  context 'as a regular user' do
    let(:user) { Fabricate(:user, email: old_email) }
    let(:updater) { EmailUpdater.new(user.guardian, user) }

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

  context 'as a staff user' do
    let(:user) { Fabricate(:moderator, email: old_email) }
    let(:updater) { EmailUpdater.new(user.guardian, user) }

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
    let(:updater) { EmailUpdater.new(user.guardian, user) }

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
