# frozen_string_literal: true

require "rails_helper"

describe PostVoting::CommentReviewQueue do
  subject(:queue) { described_class.new }

  fab!(:comment_poster) { Fabricate(:user) }
  fab!(:flagger) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, user: comment_poster, post: post) }
  let(:guardian) { Guardian.new(flagger) }
  fab!(:admin)
  let(:admin_guardian) { Guardian.new(admin) }

  describe "#flag_comment" do
    it "raises an error when the user is not allowed to flag" do
      UserSilencer.new(flagger).silence

      expect { queue.flag_comment(comment, guardian, ReviewableScore.types[:spam]) }.to raise_error(
        Discourse::InvalidAccess,
      )
    end

    it "stores the comment cooked content inside the reviewable" do
      queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

      reviewable = ReviewablePostVotingComment.last

      expect(reviewable.payload["comment_cooked"]).to eq(comment.cooked)
    end

    context "when the user already flagged the post" do
      let(:second_flag_result) do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])
      end

      before { queue.flag_comment(comment, guardian, ReviewableScore.types[:spam]) }

      it "returns an error" do
        expect(second_flag_result).to include success: false,
                errors: [I18n.t("post_voting.reviewables.comment_already_handled")]
      end

      it "returns an error when trying to use notify_moderators and the previous flag is still pending" do
        notify_moderators_result =
          queue.flag_comment(
            comment,
            guardian,
            ReviewableScore.types[:notify_moderators],
            comment: "Look at this please, moderators",
          )

        expect(notify_moderators_result).to include success: false,
                errors: [I18n.t("post_voting.reviewables.comment_already_handled")]
      end
    end

    context "when a different user already flagged the post" do
      let(:second_flag_result) { queue.flag_comment(comment, admin_guardian, second_flag_type) }

      before { queue.flag_comment(comment, guardian, ReviewableScore.types[:spam]) }

      it "appends a new score to the existing reviewable" do
        second_flag_result =
          queue.flag_comment(comment, admin_guardian, ReviewableScore.types[:off_topic])
        expect(second_flag_result).to include success: true

        reviewable = ReviewablePostVotingComment.find_by(target: comment)
        scores = reviewable.reviewable_scores

        expect(scores.size).to eq(2)
        expect(scores.map(&:reviewable_score_type)).to contain_exactly(
          *ReviewableScore.types.slice(:off_topic, :spam).values,
        )
      end

      it "returns an error when someone already used the same flag type" do
        second_flag_result =
          queue.flag_comment(comment, admin_guardian, ReviewableScore.types[:spam])

        expect(second_flag_result).to include success: false,
                errors: [I18n.t("post_voting.reviewables.comment_already_handled")]
      end
    end

    context "when a flags exists but staff already handled it" do
      let(:second_flag_result) do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])
      end

      before do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:spam])

        reviewable = ReviewablePostVotingComment.last
        reviewable.perform(admin, :ignore)
      end

      it "raises an error when we are inside the cooldown window" do
        expect(second_flag_result).to include success: false,
                errors: [I18n.t("post_voting.reviewables.comment_already_handled")]
      end

      it "allows the user to re-flag after the cooldown period" do
        reviewable = ReviewablePostVotingComment.last
        reviewable.update!(updated_at: (SiteSetting.cooldown_hours_until_reflag.to_i + 1).hours.ago)

        expect(second_flag_result).to include success: true
      end

      it "ignores the cooldown window when using the notify_moderators flag type" do
        notify_moderators_result =
          queue.flag_comment(
            comment,
            guardian,
            ReviewableScore.types[:notify_moderators],
            comment: "Look at this please, moderators",
          )

        expect(notify_moderators_result).to include success: true
      end
    end

    let(:flag_comment) { "I just flagged your post voting comment..." }

    context "when creating a notify_user flag" do
      it "creates a companion PM" do
        queue.flag_comment(
          comment,
          guardian,
          ReviewableScore.types[:notify_user],
          comment: flag_comment,
        )
        pm_topic =
          Topic.includes(:posts).find_by(user: guardian.user, archetype: Archetype.private_message)
        pm_post = pm_topic.first_post

        expect(pm_topic.allowed_users).to include(comment.user)
        expect(pm_topic.subtype).to eq(TopicSubtype.notify_user)
        expect(pm_post.raw).to include(flag_comment)
        expect(pm_topic.title).to eq(
          I18n.t("post_voting.comment.reviewable_score_types.notify_user.comment_pm_title"),
        )
      end

      it "doesn't create a reviewable" do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:notify_user])

        reviewable = ReviewablePostVotingComment.find_by(target: comment)
        expect(reviewable).to be_nil
      end

      it "doesn't create a PM if there is no comment" do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:notify_user])

        pm_topic =
          Topic.includes(:posts).find_by(user: guardian.user, archetype: Archetype.private_message)

        expect(pm_topic).to be_nil
      end

      it "allow staff to tag PM as a warning" do
        queue.flag_comment(
          comment,
          admin_guardian,
          ReviewableScore.types[:notify_user],
          comment: flag_comment,
          is_warning: true,
        )

        expect(UserWarning.exists?(user: comment.user)).to eq(true)
      end

      it "only allows staff members to send warnings" do
        expect do
          queue.flag_comment(
            comment,
            guardian,
            ReviewableScore.types[:notify_user],
            comment: flag_comment,
            is_warning: true,
          )
        end.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when creating a notify_moderators flag" do
      it "creates a companion PM and gives moderators access to it" do
        queue.flag_comment(
          comment,
          guardian,
          ReviewableScore.types[:notify_moderators],
          comment: flag_comment,
        )

        pm_topic =
          Topic.includes(:posts).find_by(user: guardian.user, archetype: Archetype.private_message)
        pm_post = pm_topic.first_post

        expect(pm_topic.allowed_groups).to contain_exactly(Group[:moderators])
        expect(pm_topic.subtype).to eq(TopicSubtype.notify_moderators)
        expect(pm_post.raw).to include(flag_comment)
        expect(pm_topic.title).to eq("A post voting comment requires staff attention")
      end

      it "creates a reviewable" do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:notify_moderators])

        reviewable = ReviewablePostVotingComment.find_by(target: comment)
        expect(reviewable).to be_present
      end

      it "ignores the is_warning flag when notifying moderators" do
        queue.flag_comment(
          comment,
          guardian,
          ReviewableScore.types[:notify_moderators],
          comment: flag_comment,
          is_warning: true,
        )

        expect(UserWarning.exists?(user: comment.user)).to eq(false)
      end
    end

    context "when immediately taking action" do
      it "agrees with the flag and deletes the post voting comment" do
        queue.flag_comment(
          comment,
          admin_guardian,
          ReviewableScore.types[:off_topic],
          take_action: true,
        )

        reviewable = ReviewablePostVotingComment.find_by(target: comment)

        expect(reviewable.approved?).to eq(true)
        expect(comment.reload.trashed?).to eq(true)
      end

      it "agrees with other flags on the same comment" do
        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

        reviewable =
          ReviewablePostVotingComment.includes(:reviewable_scores).find_by(target_id: comment)
        scores = reviewable.reviewable_scores

        expect(scores.size).to eq(1)
        expect(scores.all?(&:pending?)).to eq(true)

        queue.flag_comment(comment, admin_guardian, ReviewableScore.types[:spam], take_action: true)

        scores = reviewable.reload.reviewable_scores

        expect(scores.size).to eq(2)
        expect(scores.all?(&:agreed?)).to eq(true)
      end

      it "raises an exception if the user is not a staff member" do
        expect do
          queue.flag_comment(
            comment,
            guardian,
            ReviewableScore.types[:off_topic],
            take_action: true,
          )
        end.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when queueing for review" do
      it "sets a reason on the score" do
        queue.flag_comment(
          comment,
          admin_guardian,
          ReviewableScore.types[:off_topic],
          queue_for_review: true,
        )

        reviewable =
          ReviewablePostVotingComment.includes(:reviewable_scores).find_by(target_id: comment)
        score = reviewable.reviewable_scores.first

        expect(score.reason).to eq("post_voting_comment_queued_by_staff")
      end

      it "only allows staff members to queue for review" do
        expect do
          queue.flag_comment(
            comment,
            guardian,
            ReviewableScore.types[:off_topic],
            queue_for_review: true,
          )
        end.to raise_error(Discourse::InvalidAccess)
      end
    end

    context "when the auto silence threshold is met" do
      it "silences the user" do
        # Chat setting
        SiteSetting.chat_auto_silence_from_flags_duration = 1
        flagger.update!(trust_level: TrustLevel[4]) # Increase Score due to TL Bonus.

        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

        expect(comment_poster.reload.silenced?).to eq(true)
      end

      it "does nothing if the new score is less than the auto-silence threshold" do
        # Chat setting
        SiteSetting.chat_auto_silence_from_flags_duration = 50

        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

        expect(comment_poster.reload.silenced?).to eq(false)
      end

      it "does nothing if the silence duration is set to 0" do
        # Chat setting
        SiteSetting.chat_auto_silence_from_flags_duration = 0
        flagger.update!(trust_level: TrustLevel[4]) # Increase Score due to TL Bonus.

        queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

        expect(comment_poster.reload.silenced?).to eq(false)
      end

      context "when the target is an admin" do
        it "does not silence the user" do
          # Chat setting
          SiteSetting.chat_auto_silence_from_flags_duration = 1
          flagger.update!(trust_level: TrustLevel[4]) # Increase Score due to TL Bonus.
          comment_poster.update!(admin: true)

          queue.flag_comment(comment, guardian, ReviewableScore.types[:off_topic])

          expect(comment_poster.reload.silenced?).to eq(false)
        end
      end
    end
  end
end
