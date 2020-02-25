# frozen_string_literal: true

require 'rails_helper'

describe Jobs::InvalidateInactiveAdmins do
  fab!(:active_admin) { Fabricate(:admin, last_seen_at: 1.hour.ago) }
  before { active_admin.email_tokens.update_all(confirmed: true) }

  subject { Jobs::InvalidateInactiveAdmins.new.execute({}) }

  it "does nothing when all admins have been seen recently" do
    SiteSetting.invalidate_inactive_admin_email_after_days = 365
    subject
    expect(active_admin.reload.active).to eq(true)
    expect(active_admin.email_tokens.where(confirmed: true).exists?).to eq(true)
  end

  context "with an admin who hasn't been seen recently" do
    fab!(:not_seen_admin) { Fabricate(:admin, last_seen_at: 370.days.ago) }
    before { not_seen_admin.email_tokens.update_all(confirmed: true) }

    context 'invalidate_inactive_admin_email_after_days = 365' do
      before do
        SiteSetting.invalidate_inactive_admin_email_after_days = 365
      end

      it 'marks email tokens as unconfirmed' do
        subject
        expect(not_seen_admin.reload.email_tokens.where(confirmed: true).exists?).to eq(false)
      end

      it 'makes the user as not active and logs the action' do
        subject
        expect(not_seen_admin.reload.active).to eq(false)

        log = UserHistory.last
        expect(log.target_user_id).to eq(not_seen_admin.id)
        expect(log.action).to eq(UserHistory.actions[:deactivate_user])
      end

      it 'adds a staff log' do
        subject
        expect(not_seen_admin.reload.active).to eq(false)
      end

      context 'with social logins' do
        before do
          GithubUserInfo.create!(user_id: not_seen_admin.id, screen_name: 'bob', github_user_id: 100)
          UserAssociatedAccount.create!(provider_name: "google_oauth2", user_id: not_seen_admin.id, provider_uid: 100, info: { email: "bob@google.account.com" })
        end

        it 'removes the social logins' do
          subject
          expect(GithubUserInfo.where(user_id: not_seen_admin.id).exists?).to eq(false)
          expect(UserAssociatedAccount.where(user_id: not_seen_admin.id).exists?).to eq(false)
        end
      end

      it "doesn't deactivate admins with recent posts" do
        Fabricate(:post, user: not_seen_admin)
        subject
        expect(not_seen_admin.reload.active).to eq(true)
      end

      it "doesn't deactivate admins with recently used api keys" do
        Fabricate(:api_key, user: not_seen_admin, last_used_at: 1.day.ago)
        subject
        expect(not_seen_admin.reload.active).to eq(true)
      end
    end

    context 'invalidate_inactive_admin_email_after_days = 0 to disable this feature' do
      before do
        SiteSetting.invalidate_inactive_admin_email_after_days = 0
      end

      it 'does nothing' do
        subject
        expect(active_admin.reload.active).to eq(true)
        expect(active_admin.email_tokens.where(confirmed: true).exists?).to eq(true)
        expect(not_seen_admin.reload.active).to eq(true)
        expect(not_seen_admin.email_tokens.where(confirmed: true).exists?).to eq(true)
      end
    end
  end
end
