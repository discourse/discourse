# frozen_string_literal: true

RSpec.describe ReviewablePostVotingComment, type: :model do
  fab!(:comment_poster, :user)
  fab!(:flagger) { Fabricate(:user, group_ids: [Group::AUTO_GROUPS[:trust_level_1]]) }
  fab!(:topic) { Fabricate(:topic, subtype: Topic::POST_VOTING_SUBTYPE) }
  fab!(:post) { Fabricate(:post, topic: topic) }
  fab!(:comment) { Fabricate(:post_voting_comment, user: comment_poster, post: post) }
  let(:guardian) { Guardian.new(flagger) }
  fab!(:admin)
  let(:admin_guardian) { Guardian.new(admin) }

  fab!(:moderator)
  fab!(:user)

  fab!(:reviewable) do
    Fabricate(:reviewable_post_voting_comment, target: comment, created_by: moderator)
  end

  describe "#post" do
    it "returns the post that the comment belongs to" do
      expect(reviewable.post).to eq(post)
    end
  end

  it "agree_and_keep agrees with the flag and doesn't delete the comment" do
    reviewable.perform(moderator, :agree_and_keep_comment)

    expect(reviewable).to be_approved
    expect(comment.reload.deleted_at).not_to be_present
  end

  it "agree_and_delete agrees with the flag and deletes the comment" do
    comment_id = comment.id
    reviewable.perform(moderator, :agree_and_delete)

    expect(reviewable).to be_approved
    expect(PostVotingComment.with_deleted.find_by(id: comment_id).deleted_at).to be_present
  end

  it "agree_and_restore agrees with the flag and restores the comment" do
    comment.trash!(user)
    reviewable.perform(moderator, :agree_and_restore)

    expect(reviewable).to be_approved
    expect(comment.reload.deleted_at).to be_nil
  end

  it "perform_disagree disagrees with the flag and does nothing" do
    reviewable.perform(moderator, :disagree)

    expect(reviewable).to be_rejected
  end

  it "perform_disagree_and_restore disagrees with the flag and restores the comment" do
    comment.trash!(user)
    reviewable.perform(moderator, :disagree_and_restore)

    expect(reviewable).to be_rejected
    expect(comment.reload.deleted_at).to be_nil
  end

  it "perform_ignore ignores the flag and does nothing" do
    reviewable.perform(moderator, :ignore)

    expect(reviewable).to be_ignored
    expect(comment.reload.deleted_at).not_to be_present
  end

  context "when the flagged comment author is silenced" do
    context "when the user was silenced for this post" do
      before do
        UserSilencer.silence(
          comment_poster,
          Discourse.system_user,
          silenced_till: 10.minutes.from_now,
          reason: I18n.t("post_voting.comment.errors.auto_silence_from_flags"),
          post_id: post.id,
        )
      end

      it "perform_disagree unsilences the user" do
        reviewable.perform(moderator, :disagree)

        expect(comment_poster.reload.silenced?).to eq(false)
      end

      it "perform_disagree_and_restore unsilences the user" do
        comment.trash!(user)
        reviewable.perform(moderator, :disagree_and_restore)

        expect(comment_poster.reload.silenced?).to eq(false)
      end
    end

    context "when the user was silenced for a different reason" do
      before do
        UserSilencer.silence(
          comment_poster,
          Discourse.system_user,
          silenced_till: 10.minutes.from_now,
          reason: "unrelated reason",
        )
      end

      it "perform_disagree does not unsilence the user" do
        reviewable.perform(moderator, :disagree)

        expect(comment_poster.reload.silenced?).to eq(true)
      end

      it "perform_disagree_and_restore does not unsilence the user" do
        comment.trash!(user)
        reviewable.perform(moderator, :disagree_and_restore)

        expect(comment_poster.reload.silenced?).to eq(true)
        expect(comment.reload.deleted_at).to be_nil
      end
    end
  end

  context "when author of the flagged comment is deleted" do
    it "deletes comment and review" do
      UserDestroyer.new(Discourse.system_user).destroy(comment_poster, { delete_posts: true })
      expect { comment_poster.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { comment.reload }.to raise_error(ActiveRecord::RecordNotFound)
      expect { reviewable.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context "with category group moderators" do
    fab!(:group)
    fab!(:category_mod) { Fabricate(:user, groups: [group]) }

    before do
      SiteSetting.enable_category_group_moderation = true
      Fabricate(:category_moderation_group, category: topic.category, group: group)
    end

    context "when the user was silenced for this post" do
      before do
        UserSilencer.silence(
          comment_poster,
          Discourse.system_user,
          silenced_till: 10.minutes.from_now,
          reason: I18n.t("post_voting.comment.errors.auto_silence_from_flags"),
          post_id: post.id,
        )
      end

      it "allows category moderator to unsilence the user by disagreeing" do
        reviewable.perform(category_mod, :disagree)

        expect(reviewable).to be_rejected
        expect(comment_poster.reload.silenced?).to eq(false)
      end
    end

    context "when the user was silenced for a different post" do
      fab!(:other_post, :post)

      before do
        UserSilencer.silence(
          comment_poster,
          Discourse.system_user,
          silenced_till: 10.minutes.from_now,
          reason: "silenced for different post",
          post_id: other_post.id,
        )
      end

      it "does not allow category moderator to unsilence via unrelated reviewable" do
        reviewable.perform(category_mod, :disagree)

        expect(reviewable).to be_rejected
        expect(comment_poster.reload.silenced?).to eq(true)
      end
    end

    context "when the user was silenced by staff for unrelated reasons" do
      before do
        UserSilencer.silence(
          comment_poster,
          admin,
          silenced_till: 10.minutes.from_now,
          reason: "staff silenced for policy violation",
        )
      end

      it "does not allow category moderator to unsilence via disagreeing with flag" do
        reviewable.perform(category_mod, :disagree)

        expect(reviewable).to be_rejected
        expect(comment_poster.reload.silenced?).to eq(true)
      end
    end
  end
end
