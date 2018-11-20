require 'rails_helper'

describe Jobs::AutoQueueHandler do

  subject { Jobs::AutoQueueHandler.new.execute({}) }

  context "old flag" do
    let!(:old) { Fabricate(:flag, created_at: 61.days.ago) }
    let!(:not_old) { Fabricate(:flag, created_at: 59.days.ago) }

    it "defers the old flag if auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      subject
      expect(not_old.reload.deferred_at).to be_nil
      expect(old.reload.deferred_at).to_not be_nil
    end

    it "doesn't defer the old flag if auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      subject
      expect(not_old.reload.deferred_at).to be_nil
      expect(old.reload.deferred_at).to be_nil
    end
  end

  context "old queued post" do
    let!(:old) { Fabricate(:queued_post, created_at: 61.days.ago, queue: 'default') }
    let!(:not_old) { Fabricate(:queued_post, created_at: 59.days.ago, queue: 'default') }

    it "rejects the post when auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      subject
      expect(not_old.reload.state).to eq(QueuedPost.states[:new])
      expect(old.reload.state).to eq(QueuedPost.states[:rejected])
    end

    it "doesn't reject the post when auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      subject
      expect(not_old.reload.state).to eq(QueuedPost.states[:new])
      expect(old.reload.state).to eq(QueuedPost.states[:new])
    end
  end

end
