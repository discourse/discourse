require 'rails_helper'

RSpec.describe ReviewableFlaggedPost, type: :model do

  def pending_count
    ReviewableFlaggedPost.default_visible.pending.count
  end

  let(:user) { Fabricate(:user) }
  let(:post) { Fabricate(:post) }
  let(:moderator) { Fabricate(:moderator) }

  it "sets `potential_spam` when a spam flag is added" do
    reviewable = PostActionCreator.off_topic(user, post).reviewable
    expect(reviewable.potential_spam?).to eq(false)
    PostActionCreator.spam(Fabricate(:user), post)
    expect(reviewable.reload.potential_spam?).to eq(true)
  end

  describe "flag_stats" do
    let(:user_post) { Fabricate(:post, user: user) }
    let(:reviewable) { PostActionCreator.spam(user, post).reviewable }

    it "increases flags_agreed when agreed" do
      expect(user.user_stat.flags_agreed).to eq(0)
      reviewable.perform(Discourse.system_user, :agree_and_keep)
      expect(user.user_stat.reload.flags_agreed).to eq(1)
    end

    it "increases flags_disagreed when disagreed" do
      expect(user.user_stat.flags_disagreed).to eq(0)
      reviewable.perform(Discourse.system_user, :disagree)
      expect(user.user_stat.reload.flags_disagreed).to eq(1)
    end

    it "increases flags_ignored when ignored" do
      expect(user.user_stat.flags_ignored).to eq(0)
      reviewable.perform(Discourse.system_user, :ignore)
      expect(user.user_stat.reload.flags_ignored).to eq(1)
    end

    it "doesn't increase stats when you flag yourself" do
      expect(user.user_stat.flags_agreed).to eq(0)
      self_flag = PostActionCreator.spam(user, user_post).reviewable
      self_flag.perform(Discourse.system_user, :agree_and_keep)
      expect(user.user_stat.reload.flags_agreed).to eq(0)
    end
  end

  describe "actions" do
    let!(:result) { PostActionCreator.spam(user, post) }
    let(:reviewable) { result.reviewable }
    let(:score) { result.reviewable_score }
    let(:guardian) { Guardian.new(moderator) }

    describe "actions_for" do
      it "returns appropriate defaults" do
        actions = reviewable.actions_for(guardian)
        expect(actions.has?(:agree_and_hide)).to eq(true)
        expect(actions.has?(:agree_and_keep)).to eq(true)
        expect(actions.has?(:agree_and_silence)).to eq(true)
        expect(actions.has?(:agree_and_suspend)).to eq(true)
        expect(actions.has?(:delete_spammer)).to eq(true)
        expect(actions.has?(:disagree)).to eq(true)
        expect(actions.has?(:ignore)).to eq(true)
        expect(actions.has?(:delete_and_ignore)).to eq(true)
        expect(actions.has?(:delete_and_agree)).to eq(true)

        expect(actions.has?(:disagree_and_restore)).to eq(false)
      end

      it "returns `agree_and_restore` if the post is user deleted" do
        post.update(user_deleted: true)
        expect(reviewable.actions_for(guardian).has?(:agree_and_restore)).to eq(true)
      end

      it "returns appropriate actions for a hidden post" do
        post.update(hidden: true, hidden_at: Time.now)
        expect(reviewable.actions_for(guardian).has?(:agree_and_hide)).to eq(false)
        expect(reviewable.actions_for(guardian).has?(:disagree_and_restore)).to eq(true)
      end

      it "won't return the penalty options if the user is not regular" do
        post.user.update(moderator: true)
        expect(reviewable.actions_for(guardian).has?(:agree_and_silence)).to eq(false)
        expect(reviewable.actions_for(guardian).has?(:agree_and_suspend)).to eq(false)
      end
    end

    it "agree_and_keep agrees with the flags and keeps the post" do
      reviewable.perform(moderator, :agree_and_keep)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).not_to be_hidden
    end

    it "agree_and_suspend agrees with the flags and keeps the post" do
      reviewable.perform(moderator, :agree_and_suspend)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).not_to be_hidden
    end

    it "agree_and_silence agrees with the flags and keeps the post" do
      reviewable.perform(moderator, :agree_and_silence)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).not_to be_hidden
    end

    it "agree_and_hide agrees with the flags and hides the post" do
      reviewable.perform(moderator, :agree_and_hide)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).to be_hidden
    end

    it "agree_and_restore agrees with the flags and restores the post" do
      post.update(user_deleted: true)
      reviewable.perform(moderator, :agree_and_restore)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.user_deleted?).to eq(false)
    end

    it "supports deleting a spammer" do
      reviewable.perform(moderator, :delete_spammer)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.reload.deleted_at).to be_present
      expect(User.find_by(id: reviewable.target_created_by_id)).to be_blank
    end

    it "ignores the flags" do
      reviewable.perform(moderator, :ignore)
      expect(reviewable).to be_ignored
      expect(score.reload).to be_ignored
    end

    it "delete_and_defer ignores the flags and deletes post" do
      reviewable.perform(moderator, :delete_and_ignore)
      expect(reviewable).to be_ignored
      expect(score.reload).to be_ignored
      expect(post.reload.deleted_at).to be_present
    end

    it "delete_and_agree agrees with the flags and deletes post" do
      reviewable.perform(moderator, :delete_and_agree)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.reload.deleted_at).to be_present
    end

    it "disagrees with the flags" do
      reviewable.perform(moderator, :disagree)
      expect(reviewable).to be_rejected
      expect(score.reload).to be_disagreed
    end

    it "disagrees with the flags and restores the post" do
      post.update(hidden: true, hidden_at: Time.now)
      reviewable.perform(moderator, :disagree_and_restore)
      expect(reviewable).to be_rejected
      expect(score.reload).to be_disagreed
      expect(post.user_deleted?).to eq(false)
    end

  end

  describe "pending count" do
    it "increments the numbers correctly" do
      expect(pending_count).to eq(0)

      result = PostActionCreator.off_topic(user, post)
      expect(pending_count).to eq(1)

      result.reviewable.perform(Discourse.system_user, :disagree)
      expect(pending_count).to eq(0)
    end

    it "respects min_score_default_visibility" do
      SiteSetting.min_score_default_visibility = 7.5
      expect(pending_count).to eq(0)

      PostActionCreator.off_topic(user, post)
      expect(pending_count).to eq(0)

      PostActionCreator.spam(moderator, post)
      expect(pending_count).to eq(1)
    end

    it "should reset counts when a topic is deleted" do
      PostActionCreator.off_topic(user, post)
      expect(pending_count).to eq(1)

      PostDestroyer.new(moderator, post).destroy
      expect(pending_count).to eq(0)
    end

    it "should not review non-human users" do
      post = create_post(user: Discourse.system_user)
      reviewable = PostActionCreator.off_topic(user, post).reviewable
      expect(reviewable).to be_blank
      expect(pending_count).to eq(0)
    end

    it "should ignore handled flags" do
      post = create_post
      reviewable = PostActionCreator.off_topic(user, post).reviewable
      expect(post.hidden).to eq(false)
      expect(post.hidden_at).to be_blank

      reviewable.perform(moderator, :ignore)
      expect(pending_count).to eq(0)

      post.reload
      expect(post.hidden).to eq(false)
      expect(post.hidden_at).to be_blank

      post.hide!(PostActionType.types[:off_topic])

      post.reload
      expect(post.hidden).to eq(true)
      expect(post.hidden_at).to be_present
    end

  end

end
