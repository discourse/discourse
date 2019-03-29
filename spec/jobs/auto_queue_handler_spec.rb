require 'rails_helper'

describe Jobs::AutoQueueHandler do

  subject { Jobs::AutoQueueHandler.new.execute({}) }

  context "old flag" do
    let!(:old) { Fabricate(:reviewable_flagged_post, created_at: 61.days.ago) }
    let!(:not_old) { Fabricate(:reviewable_flagged_post, created_at: 59.days.ago) }

    it "defers the old flag if auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      subject
      expect(not_old.reload).to be_pending
      expect(old.reload).not_to be_pending
    end

    it "doesn't defer the old flag if auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      subject
      expect(not_old.reload).to be_pending
      expect(old.reload).to be_pending
    end
  end

  context "reviewables" do
    let!(:new_post) { Fabricate(:reviewable_queued_post, created_at: 59.days.ago) }
    let!(:old_post) { Fabricate(:reviewable_queued_post, created_at: 61.days.ago) }
    let!(:new_user) { Fabricate(:reviewable, created_at: 10.days.ago) }
    let!(:old_user) { Fabricate(:reviewable, created_at: 80.days.ago) }

    it "rejects the post when auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      subject
      expect(new_post.reload.pending?).to eq(true)
      expect(old_post.reload.rejected?).to eq(true)
      expect(new_user.reload.pending?).to eq(true)
      expect(old_user.reload.rejected?).to eq(true)
    end

    it "leaves reviewables as pending auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      subject
      expect(new_post.reload.pending?).to eq(true)
      expect(new_user.reload.pending?).to eq(true)
      expect(old_post.reload.pending?).to eq(true)
      expect(old_user.reload.pending?).to eq(true)
    end
  end

end
