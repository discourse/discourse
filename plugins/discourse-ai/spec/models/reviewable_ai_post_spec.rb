# frozen_string_literal: true

describe ReviewableAiPost do
  subject(:reviewable_ai_post) { described_class.new }

  fab!(:target, :post)

  before { enable_current_plugin }

  describe "#build_actions" do
    let(:guardian) { Guardian.new }

    let(:reviewable) do
      reviewable_ai_post.tap do |r|
        r.target = target
        r.target_created_by = target.user
        r.created_by = Discourse.system_user
      end
    end

    def reviewable_actions(a_guardian)
      actions = Reviewable::Actions.new(reviewable, a_guardian, {})
      reviewable.build_actions(actions, a_guardian, {})

      actions
    end

    context "when the reviewable isn't pending" do
      before { reviewable.status = Reviewable.statuses[:rejected] }

      it "returns no actions" do
        expect(reviewable_actions(guardian)).to be_blank
      end
    end

    describe "actions that don't require special permissions" do
      it "has the disagree action" do
        expect(reviewable_actions(guardian).has?(:disagree)).to eq(true)
      end

      it "has the ignore action" do
        expect(reviewable_actions(guardian).has?(:ignore)).to eq(true)
      end

      it "has the agree and hide or agree and keep actions" do
        actions = reviewable_actions(guardian)

        expect(actions.has?(:agree_and_hide)).to eq(true)
        expect(actions.has?(:agree_and_keep)).to eq(true)
        expect(actions.has?(:agree_and_keep_hidden)).to eq(false)
      end

      it "doesn't have the penalize actions" do
        actions = reviewable_actions(guardian)

        expect(actions.has?(:agree_and_suspend)).to eq(false)
        expect(actions.has?(:agree_and_silence)).to eq(false)
      end

      it "doesn't has the delete + replies actions" do
        actions = reviewable_actions(guardian)

        expect(actions.has?(:delete_and_ignore_replies)).to eq(false)
        expect(actions.has?(:delete_and_agree_replies)).to eq(false)
      end

      context "when the post is hidden" do
        before { target.hide!(PostActionType.types[:inappropriate]) }

        it "can agree and keep hidden" do
          actions = reviewable_actions(guardian)

          expect(actions.has?(:agree_and_hide)).to eq(false)
          expect(actions.has?(:agree_and_keep)).to eq(false)
          expect(actions.has?(:agree_and_keep_hidden)).to eq(true)
        end

        it "has the disagree and restore action" do
          actions = reviewable_actions(guardian)

          expect(actions.has?(:disagree)).to eq(false)
          expect(actions.has?(:disagree_and_restore)).to eq(true)
        end
      end

      context "when the post was deleted by the user" do
        before { target.user_deleted = true }

        it "lets you restore it but not hiding it" do
          actions = reviewable_actions(guardian)

          expect(actions.has?(:agree_and_restore)).to eq(true)
          expect(actions.has?(:agree_and_keep)).to eq(true)
          expect(actions.has?(:agree_and_keep_hidden)).to eq(false)
          expect(actions.has?(:agree_and_hide)).to eq(false)
        end
      end
    end

    context "when the reviewer can suspend the poster" do
      let(:mod_guardian) { Guardian.new(Fabricate(:moderator)) }

      it "has the penalization actions" do
        actions = reviewable_actions(mod_guardian)

        expect(actions.has?(:agree_and_suspend)).to eq(true)
        expect(actions.has?(:agree_and_silence)).to eq(true)
      end
    end

    context "when the reviewer can delete the post and topic" do
      let(:mod_guardian) { Guardian.new(Fabricate(:moderator)) }

      it "has the delete + replies actions" do
        target.reply_count = 3
        actions = reviewable_actions(mod_guardian)

        expect(actions.has?(:delete_and_ignore_replies)).to eq(true)
        expect(actions.has?(:delete_and_agree_replies)).to eq(true)
      end
    end
  end

  describe "#perform" do
    let(:reviewable) do
      described_class.needs_review!(target: target, created_by: Discourse.system_user)
    end
    fab!(:admin)

    before do
      reviewable.add_score(
        Discourse.system_user,
        ReviewableScore.types[:inappropriate],
        created_at: reviewable.created_at,
      )
    end

    describe "agree variations" do
      it "hides the topic when performing the agree_and_hide action" do
        result = reviewable.perform(admin, :agree_and_hide)

        expect(result.transition_to).to eq :approved
        expect(target.reload.hidden?).to eq(true)
      end

      it "doesn't unhide the topic when performing the agree_and_keep_hidden action" do
        target.hide!(ReviewableScore.types[:inappropriate])

        result = reviewable.perform(admin, :agree_and_keep_hidden)

        expect(result.transition_to).to eq :approved
        expect(target.reload.hidden?).to eq(true)
      end

      it "un-deletes the post when performing the agree_and_restore action" do
        target.update!(deleted_at: 1.minute.ago, deleted_by: target.user, user_deleted: true)

        result = reviewable.perform(admin, :agree_and_restore)

        expect(result.transition_to).to eq :approved
        expect(target.reload.deleted_at).to be_nil
        expect(target.user_deleted).to eq(false)
      end
    end

    describe "disagree variations" do
      it "disagree_and_restore disagrees with the flag and unhides the post" do
        target.hide!(ReviewableScore.types[:inappropriate])

        result = reviewable.perform(admin, :disagree_and_restore)

        expect(result.transition_to).to eq :rejected
        expect(target.reload.hidden?).to eq(false)
      end

      it "disagree disagrees with the flag" do
        result = reviewable.perform(admin, :disagree)

        expect(result.transition_to).to eq :rejected
      end
    end

    describe "delete post variations" do
      def create_reply(post)
        PostCreator.create(
          Fabricate(:user),
          raw: "this is the reply text",
          reply_to_post_number: post.post_number,
          topic_id: post.topic_id,
        )
      end

      before { target.update!(reply_count: 1) }

      it "ignores the reviewable with delete_and_ignore" do
        result = reviewable.perform(admin, :delete_and_ignore)

        expect(result.transition_to).to eq :ignored
        expect(target.reload.deleted_at).to be_present
      end

      it "ignores the reviewable and replies with delete_and_ignore_replies" do
        reply = create_reply(target)

        result = reviewable.perform(admin, :delete_and_ignore_replies)

        expect(result.transition_to).to eq :ignored
        expect(target.reload.deleted_at).to be_present
        expect(reply.reload.deleted_at).to be_present
      end

      it "agrees with the reviewable with delete_and_agree" do
        result = reviewable.perform(admin, :delete_and_agree)

        expect(result.transition_to).to eq :approved
        expect(target.reload.deleted_at).to be_present
      end

      it "agrees with the reviewables and its replies with delete_and_agree_replies" do
        reply = create_reply(target)

        result = reviewable.perform(admin, :delete_and_agree_replies)

        expect(result.transition_to).to eq :approved
        expect(target.reload.deleted_at).to be_present
        expect(reply.reload.deleted_at).to be_present
      end
    end

    describe "delete user variations" do
      it "deletes the user and agrees with the reviewable" do
        result = reviewable.perform(admin, :delete_user)

        expect(result.transition_to).to eq :approved
        expect { target.user.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    it "ignores the reviewable" do
      result = reviewable.perform(admin, :ignore)

      expect(result.transition_to).to eq :ignored
    end
  end
end
