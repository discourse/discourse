# frozen_string_literal: true

RSpec.describe ReviewableFlaggedPost, type: :model do
  def pending_count
    ReviewableFlaggedPost.default_visible.pending.count
  end

  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:post)
  fab!(:moderator) { Fabricate(:moderator, refresh_auto_groups: true) }

  it "sets `potential_spam` when a spam flag is added" do
    reviewable = PostActionCreator.off_topic(user, post).reviewable
    expect(reviewable.potential_spam?).to eq(false)
    PostActionCreator.spam(Fabricate(:user, refresh_auto_groups: true), post)
    expect(reviewable.reload.potential_spam?).to eq(true)
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
        expect(actions.has?(:agree_and_edit)).to eq(true)
        expect(actions.has?(:agree_and_keep_hidden)).to eq(false)
        expect(actions.has?(:agree_and_silence)).to eq(true)
        expect(actions.has?(:agree_and_suspend)).to eq(true)
        expect(actions.has?(:delete_user)).to eq(true)
        expect(actions.has?(:delete_user_block)).to eq(true)
        expect(actions.has?(:disagree)).to eq(true)
        expect(actions.has?(:ignore_and_do_nothing)).to eq(true)
        expect(actions.has?(:delete_and_ignore)).to eq(true)
        expect(actions.has?(:delete_and_ignore_replies)).to eq(false)
        expect(actions.has?(:delete_and_agree)).to eq(true)
        expect(actions.has?(:delete_and_replies)).to eq(false)

        expect(actions.has?(:disagree_and_restore)).to eq(false)
      end

      it "doesn't include deletes for category topics" do
        c = Fabricate(:category_with_definition)
        flag = PostActionCreator.spam(user, c.topic.posts.first).reviewable
        actions = flag.actions_for(guardian)
        expect(actions.has?(:delete_and_ignore)).to eq(false)
        expect(actions.has?(:delete_and_ignore_replies)).to eq(false)
        expect(actions.has?(:delete_and_agree)).to eq(false)
        expect(actions.has?(:delete_and_replies)).to eq(false)
      end

      it "changes `agree_and_keep` to `agree_and_keep_hidden` if it's been hidden" do
        post.hidden = true
        actions = reviewable.actions_for(guardian)
        expect(actions.has?(:agree_and_keep)).to eq(false)
        expect(actions.has?(:agree_and_edit)).to eq(false)
        expect(actions.has?(:agree_and_keep_hidden)).to eq(true)
      end

      it "returns `agree_and_restore` if the post is user deleted" do
        post.update(user_deleted: true)
        expect(reviewable.actions_for(guardian).has?(:agree_and_restore)).to eq(true)
      end

      it "returns delete replies options if there are replies" do
        post.update(reply_count: 3)
        expect(reviewable.actions_for(guardian).has?(:delete_and_agree_replies)).to eq(true)
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

      it "doesn't end up with an empty ignore bundle when the post is already hidden and deleted" do
        post.update!(hidden: true)
        post.topic.trash!
        post.trash!
        expect(reviewable.actions_for(guardian).has?(:ignore_and_do_nothing)).to eq(false)
        expect(reviewable.actions_for(guardian).has?(:delete_and_ignore)).to eq(false)
        expect(
          reviewable.actions_for(guardian).bundles.find { |bundle| bundle.id.include?("-ignore") },
        ).to be_blank
      end

      context "when flagged as potential_spam" do
        before { reviewable.update!(potential_spam: true) }

        it "excludes delete action if the reviewer cannot delete the user" do
          post.user.user_stat.update!(
            first_post_created_at: 1.year.ago,
            post_count: User::MAX_STAFF_DELETE_POST_COUNT + 1,
          )

          expect(reviewable.actions_for(guardian).has?(:delete_user)).to be false
          expect(reviewable.actions_for(guardian).has?(:delete_user_block)).to be false
        end

        it "includes delete actions if the reviewer can delete the user" do
          expect(reviewable.actions_for(guardian).has?(:delete_user)).to be true
          expect(reviewable.actions_for(guardian).has?(:delete_user_block)).to be true
        end
      end

      context "when flagged as illegal" do
        before do
          reviewable.add_score(
            Discourse.system_user,
            ReviewableScore.types[:illegal],
            reason: "Looks pretty sus.",
          )
          reviewable.update(potential_spam: false)
        end

        it "excludes delete action if the reviewer cannot delete the user" do
          post.user.user_stat.update!(
            first_post_created_at: 1.year.ago,
            post_count: User::MAX_STAFF_DELETE_POST_COUNT + 1,
          )

          expect(reviewable.actions_for(guardian).has?(:delete_user)).to be false
          expect(reviewable.actions_for(guardian).has?(:delete_user_block)).to be false
        end

        it "includes delete actions if the reviewer can delete the user" do
          expect(reviewable.actions_for(guardian).has?(:delete_user)).to be true
          expect(reviewable.actions_for(guardian).has?(:delete_user_block)).to be true
        end
      end

      context "for ignore_and_do_nothing" do
        it "does not return `ignore_and_do_nothing` when post is hidden" do
          post.update(hidden: true)

          expect(reviewable.actions_for(guardian).has?(:ignore_and_do_nothing)).to eq(false)
        end

        it "returns `ignore_and_do_nothing` if the acting user is system" do
          post.update(hidden: true)
          system_guardian = Guardian.new(Discourse.system_user)

          expect(reviewable.actions_for(system_guardian).has?(:ignore_and_do_nothing)).to eq(true)
        end
      end
    end

    it "agree_and_keep agrees with the flags and keeps the post" do
      reviewable.perform(moderator, :agree_and_keep)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).not_to be_hidden
    end

    it "agree_and_keep agrees with the flags and edits the post" do
      reviewable.perform(moderator, :agree_and_keep)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post).not_to be_hidden
    end

    describe "with reviewable claiming enabled" do
      fab!(:claimed) { Fabricate(:reviewable_claimed_topic, topic: post.topic, user: moderator) }
      it "clears the claimed topic on resolve" do
        SiteSetting.reviewable_claiming = "required"
        reviewable.perform(moderator, :agree_and_keep)
        expect(reviewable).to be_approved
        expect(score.reload).to be_agreed
        expect(post).not_to be_hidden
        expect(ReviewableClaimedTopic.where(topic_id: post.topic.id).exists?).to eq(false)
        expect(
          post
            .topic
            .reviewables
            .first
            .history
            .where(reviewable_history_type: ReviewableHistory.types[:unclaimed])
            .size,
        ).to eq(1)
      end
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
      reviewable.perform(moderator, :delete_user_block)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.reload.deleted_at).to be_present
      expect(User.find_by(id: reviewable.target_created_by_id)).to be_blank
    end

    it "ignores the flags" do
      reviewable.perform(moderator, :ignore_and_do_nothing)
      expect(reviewable).to be_ignored
      expect(score.reload).to be_ignored
    end

    it "delete_and_ignore ignores the flags and deletes post" do
      reviewable.perform(moderator, :delete_and_ignore)
      expect(reviewable).to be_ignored
      expect(score.reload).to be_ignored
      expect(post.reload.deleted_at).to be_present
    end

    it "delete_and_ignore_replies ignores the flags and deletes post + replies" do
      reply = create_reply(post)
      nested_reply = create_reply(reply)
      post.reload

      reviewable.perform(moderator, :delete_and_ignore_replies)
      expect(reviewable).to be_ignored
      expect(score.reload).to be_ignored
      expect(post.reload.deleted_at).to be_present
      expect(reply.reload.deleted_at).to be_present
      expect(nested_reply.reload.deleted_at).to be_present
    end

    it "delete_and_agree agrees with the flags and deletes post" do
      reviewable.perform(moderator, :delete_and_agree)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.reload.deleted_at).to be_present
    end

    it "delete_and_agree_replies agrees w/ the flags and deletes post + replies" do
      reply = create_reply(post)
      nested_reply = create_reply(reply)
      post.reload

      reviewable.perform(moderator, :delete_and_agree_replies)
      expect(reviewable).to be_approved
      expect(score.reload).to be_agreed
      expect(post.reload.deleted_at).to be_present
      expect(reply.reload.deleted_at).to be_present
      expect(nested_reply.reload.deleted_at).to be_present
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
      expect(post.hidden?).to eq(false)
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

    it "respects `reviewable_default_visibility`" do
      Reviewable.set_priorities(high: 7.5)
      SiteSetting.reviewable_default_visibility = "high"
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

      reviewable.perform(moderator, :ignore_and_do_nothing)
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

  describe "#perform_delete_and_agree" do
    it "notifies the user about the flagged post deletion" do
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.add_score(
        moderator,
        PostActionType.types[:spam],
        created_at: reviewable.created_at,
      )

      reviewable.perform(moderator, :delete_and_agree)

      assert_pm_creation_enqueued(reviewable.post.user_id, "flags_agreed_and_post_deleted")
    end
  end

  describe "#perform_delete_and_agree_replies" do
    let(:flagged_post) { Fabricate(:reviewable_flagged_post) }
    let!(:reply) { create_reply(flagged_post.target) }

    before { flagged_post.target.update(reply_count: 1) }

    it "ignore flagged replies" do
      flagged_reply = Fabricate(:reviewable_flagged_post, target: reply)
      flagged_post.perform(moderator, :delete_and_agree_replies)

      expect(flagged_reply.reload).to be_ignored
    end

    it "notifies users that responded to flagged post" do
      SiteSetting.notify_users_after_responses_deleted_on_flagged_post = true
      flagged_post.perform(moderator, :delete_and_agree_replies)

      expect(Jobs::SendSystemMessage.jobs.size).to eq(2)
      expect(Jobs::SendSystemMessage.jobs.last["args"].first["message_type"]).to eq(
        "flags_agreed_and_post_deleted_for_responders",
      )
    end

    it "skips responders notification when the score type doesn't match any post action flag type" do
      flagged_post.reviewable_scores.first.update!(
        reviewable_score_type: ReviewableScore.types[:needs_approval],
      )

      expect { flagged_post.perform(moderator, :delete_and_agree_replies) }.not_to change(
        Jobs::SendSystemMessage.jobs,
        :size,
      )
    end

    it "ignores flagged responses" do
      SiteSetting.notify_users_after_responses_deleted_on_flagged_post = true
      flagged_reply = Fabricate(:reviewable_flagged_post, target: reply)
      Fabricate(
        :post,
        reply_to_post_number: flagged_reply.target.post_number,
        topic: flagged_reply.target.topic,
      )
      flagged_post.perform(moderator, :delete_and_agree_replies)

      expect(flagged_reply.reload).to be_ignored
    end
  end

  describe "#perform_disagree_and_restore" do
    it "notifies the user about the flagged post being restored" do
      reviewable = Fabricate(:reviewable_flagged_post)
      reviewable.post.update(
        hidden: true,
        hidden_at: Time.zone.now,
        hidden_reason_id: PostActionType.types[:spam],
      )

      reviewable.perform(moderator, :disagree_and_restore)

      assert_pm_creation_enqueued(reviewable.post.user_id, "flags_disagreed")
    end
  end

  describe "recalculating the reviewable score" do
    let(:expected_score) { 8 }
    let(:reviewable) { Fabricate(:reviewable_flagged_post, score: expected_score) }

    it "doesn't recalculate the score after ignore" do
      reviewable.perform(moderator, :ignore_and_do_nothing)

      expect(reviewable.score).to eq(expected_score)
    end

    it "doesn't recalculate the score after disagree" do
      reviewable.perform(moderator, :disagree)

      expect(reviewable.score).to eq(expected_score)
    end
  end

  def assert_pm_creation_enqueued(user_id, pm_type)
    expect(Jobs::SendSystemMessage.jobs.length).to eq(1)
    job = Jobs::SendSystemMessage.jobs[0]
    expect(job["args"][0]["user_id"]).to eq(user_id)
    expect(job["args"][0]["message_type"]).to eq(pm_type)
  end

  def create_reply(post)
    PostCreator.create(
      Fabricate(:user),
      raw: "this is the reply text",
      reply_to_post_number: post.post_number,
      topic_id: post.topic,
    )
  end
end
