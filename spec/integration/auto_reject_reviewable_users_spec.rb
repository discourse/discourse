# frozen_string_literal: true

RSpec.describe "auto reject reviewable users" do
  describe "reviewable users" do
    fab!(:old_user) { Fabricate(:reviewable, created_at: 80.days.ago) }

    it "does not send email to rejected user" do
      SiteSetting.must_approve_users = true
      SiteSetting.auto_handle_queued_age = 60

      Jobs::CriticalUserEmail.any_instance.expects(:execute).never
      Jobs::AutoQueueHandler.new.execute({})

      expect(old_user.reload.rejected?).to eq(true)
      expect(UserHistory.last.context).to eq(I18n.t("user.destroy_reasons.reviewable_reject_auto"))
    end
  end
end
