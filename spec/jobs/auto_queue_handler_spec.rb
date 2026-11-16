# frozen_string_literal: true

RSpec.describe Jobs::AutoQueueHandler do
  subject(:job) { Jobs::AutoQueueHandler.new.execute({}) }

  describe "old flagged post" do
    fab!(:spam_result) do
      PostActionCreator.new(
        Fabricate(:user, refresh_auto_groups: true),
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

  describe "re-opened flag" do
    fab!(:moderator)
    fab!(:post)
    fab!(:flagger) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:other_flagger) { Fabricate(:user, refresh_auto_groups: true) }

    let!(:reviewable) do
      freeze_time(100.days.ago) do
        PostActionCreator
          .spam(flagger, post)
          .reviewable
          .tap { |flag| flag.perform(moderator, :ignore_and_do_nothing) }
      end
    end

    before { SiteSetting.auto_handle_queued_age = 60 }

    it "leaves a flag re-opened within auto_handle_queued_age days pending" do
      PostActionCreator.spam(other_flagger, post)

      job

      expect(reviewable.reload).to be_pending
    end

    it "ignores a flag re-opened more than auto_handle_queued_age days ago" do
      freeze_time(61.days.ago) { PostActionCreator.spam(other_flagger, post) }

      expect { job }.to change { reviewable.reload.status }.from("pending").to("ignored")
    end
  end
end
