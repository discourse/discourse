# frozen_string_literal: true

RSpec.describe Jobs::AutoQueueHandler do
  subject(:job) { Jobs::AutoQueueHandler.new.execute({}) }

  describe "old flagged post" do
    fab!(:spam_result) do
      PostActionCreator.new(
        Fabricate(:user),
        Fabricate(:post),
        PostActionType.types[:spam],
        message: "this is the initial message",
      ).perform
    end

    fab!(:post_action) { spam_result.post_action }
    fab!(:old) do
      spam_result.reviewable.update_column(:created_at, 61.days.ago)
      spam_result.reviewable
    end

    fab!(:not_old) { Fabricate(:reviewable_flagged_post, created_at: 59.days.ago) }

    it "defers the old flag if auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      job
      expect(not_old.reload).to be_pending
      expect(old.reload).not_to be_pending
      expect(post_action.related_post.topic.posts_count).to eq(1)
    end

    it "doesn't defer the old flag if auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      job
      expect(not_old.reload).to be_pending
      expect(old.reload).to be_pending
    end
  end

  describe "reviewables" do
    fab!(:new_post) { Fabricate(:reviewable_queued_post, created_at: 59.days.ago) }
    fab!(:old_post) { Fabricate(:reviewable_queued_post, created_at: 61.days.ago) }
    fab!(:new_user) { Fabricate(:reviewable, created_at: 10.days.ago) }
    fab!(:old_user) { Fabricate(:reviewable, created_at: 80.days.ago) }

    it "rejects the post when auto_handle_queued_age is 60" do
      SiteSetting.auto_handle_queued_age = 60
      job
      expect(new_post.reload.pending?).to eq(true)
      expect(old_post.reload.rejected?).to eq(true)
      expect(new_user.reload.pending?).to eq(true)
      expect(old_user.reload.rejected?).to eq(true)
    end

    it "leaves reviewables as pending auto_handle_queued_age is 0" do
      SiteSetting.auto_handle_queued_age = 0
      job
      expect(new_post.reload.pending?).to eq(true)
      expect(new_user.reload.pending?).to eq(true)
      expect(old_post.reload.pending?).to eq(true)
      expect(old_user.reload.pending?).to eq(true)
    end
  end
end
