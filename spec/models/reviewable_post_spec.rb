# frozen_string_literal: true

RSpec.describe ReviewablePost do
  fab!(:admin)

  describe "#build_actions" do
    # TODO (reviewable-refresh): Remove the tests below when the legacy combined actions are removed
    let(:post) { Fabricate.build(:post) }
    let(:reviewable) { ReviewablePost.new(target: post) }
    let(:guardian) { Guardian.new }

    it "Does not return available actions when the reviewable is no longer pending" do
      available_actions =
        (Reviewable.statuses.keys - ["pending"]).reduce([]) do |actions, status|
          reviewable.status = status

          actions.concat reviewable_actions(guardian).to_a
        end

      expect(available_actions).to be_empty
    end

    it "only shows the approve post action if users cannot delete the post" do
      expect(reviewable_actions(guardian).has?(:approve)).to eq(true)
      expect(reviewable_actions(guardian).has?(:reject_and_delete)).to eq(false)
    end

    it "includes the reject and delete action if the user is allowed" do
      expect(reviewable_actions(Guardian.new(admin)).has?(:reject_and_delete)).to eq(true)
    end

    it "includes the approve post and unhide action if the post is hidden" do
      post.hidden = true

      actions = reviewable_actions(guardian)

      expect(actions.has?(:approve_and_unhide)).to eq(true)
    end

    it "includes the reject post and keep deleted action is the post is deleted" do
      post.deleted_at = 1.day.ago

      actions = reviewable_actions(guardian)

      expect(actions.has?(:approve_and_restore)).to eq(false)
      expect(actions.has?(:reject_and_keep_deleted)).to eq(true)
    end

    it "includes an option to approve and restore the post if the user is allowed" do
      post.deleted_at = 1.day.ago

      actions = reviewable_actions(Guardian.new(admin))

      expect(actions.has?(:approve_and_restore)).to eq(false)
    end

    def reviewable_actions(guardian)
      actions = Reviewable::Actions.new(reviewable, guardian, {})
      reviewable.build_actions(actions, guardian, {})

      actions
    end
    # TODO (reviewable-refresh): Remove the tests above when the legacy combined actions are removed

    context "with new UI (separated post and user actions)" do
      let(:post) { Fabricate.build(:post) }
      let(:reviewable) { ReviewablePost.new(target: post, target_created_by: post.user) }
      let(:guardian) { Guardian.new }
      let(:admin_guardian) { Guardian.new(admin) }

      before do
        allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
      end

      it "Does not return available actions when the reviewable is no longer pending" do
        available_actions =
          (Reviewable.statuses.keys - ["pending"]).reduce([]) do |actions, status|
            reviewable.status = status
            actions.concat reviewable_actions(guardian).to_a
          end

        expect(available_actions).to be_empty
      end

      it "returns two bundles for post and user actions" do
        actions = reviewable_actions(guardian)
        bundles = actions.bundles

        expect(bundles.count).to eq(2)
        expect(bundles.map(&:id)).to include(
          "#{reviewable.id}-post-actions",
          "#{reviewable.id}-user-actions",
        )
      end

      it "includes appropriate post actions for normal posts" do
        actions = reviewable_actions(guardian)

        expect(actions.has?(:no_action_post)).to eq(true)
        expect(actions.has?(:hide_post)).to eq(true)
        expect(actions.has?(:edit_post)).to eq(true)
      end

      it "includes delete_post action for admins" do
        expect(reviewable_actions(admin_guardian).has?(:delete_post)).to eq(true)
        expect(reviewable_actions(guardian).has?(:delete_post)).to eq(false)
      end

      it "includes appropriate post actions for hidden posts" do
        post.hidden = true
        actions = reviewable_actions(guardian)

        expect(actions.has?(:no_action_post)).to eq(true)
        expect(actions.has?(:unhide_post)).to eq(true)
        expect(actions.has?(:hide_post)).to eq(false)
      end

      it "includes appropriate post actions for deleted posts" do
        post.deleted_at = 1.day.ago
        actions = reviewable_actions(guardian)

        expect(actions.has?(:no_action_post)).to eq(true)
        expect(actions.has?(:restore_post)).to eq(false) # non-admin can't restore
      end

      it "includes restore action for deleted posts when admin" do
        post.deleted_at = 1.day.ago
        actions = reviewable_actions(admin_guardian)

        expect(actions.has?(:restore_post)).to eq(false) # admin can't restore in this test setup
      end

      it "includes user actions when target_created_by is present" do
        actions = reviewable_actions(guardian)

        expect(actions.has?(:no_action_user)).to eq(true)
      end

      it "includes suspend and silence actions for admins" do
        actions = reviewable_actions(admin_guardian)

        expect(actions.has?(:suspend_user)).to eq(true)
        expect(actions.has?(:silence_user)).to eq(true)
      end

      it "includes delete user actions for admins" do
        actions = reviewable_actions(admin_guardian)

        expect(actions.has?(:delete_user)).to eq(true)
        expect(actions.has?(:delete_and_block_user)).to eq(true)
      end

      it "includes a minimal user actions bundle when no target_created_by" do
        reviewable.target_created_by = nil
        actions = reviewable_actions(guardian)

        expect(actions.has?(:no_action_user)).to eq(true)
        expect(actions.has?(:silence_user)).to eq(false)
        expect(actions.has?(:suspend_user)).to eq(false)
        expect(actions.has?(:delete_user)).to eq(false)
        expect(actions.has?(:delete_and_block_user)).to eq(false)
      end

      def reviewable_actions(guardian)
        actions = Reviewable::Actions.new(reviewable, guardian, {})
        reviewable.build_actions(actions, guardian, {})

        actions
      end
    end
  end

  describe "Performing actions" do
    let(:post) { Fabricate(:post) }
    let(:reviewable) { ReviewablePost.needs_review!(target: post, created_by: admin) }

    before { reviewable.created_new! }

    # TODO (reviewable-refresh): Remove the tests below when the legacy combined actions are removed
    describe "#perform_approve" do
      it "transitions to the approved state" do
        result = reviewable.perform admin, :approve

        expect(result.transition_to).to eq :approved
      end
    end

    describe "#perform_reject_and_suspend" do
      it "transitions to the rejected state" do
        result = reviewable.perform admin, :reject_and_suspend

        expect(result.transition_to).to eq :rejected
      end
    end

    describe "#perform_reject_and_keep_deleted" do
      it "transitions to the rejected state and keep the post deleted" do
        post.trash!

        result = reviewable.perform admin, :reject_and_keep_deleted

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
      end
    end

    describe "#perform_approve_and_restore" do
      it "transitions to the approved state and restores the post" do
        post.trash!

        result = reviewable.reload.perform admin, :approve_and_restore

        expect(result.transition_to).to eq :approved
        expect(Post.where(id: post.id).exists?).to eq(true)
      end
    end

    describe "#perform_approve_and_unhide" do
      it "transitions to the approved state and unhides the post" do
        post.update!(hidden: true)

        result = reviewable.reload.perform admin, :approve_and_unhide

        expect(result.transition_to).to eq :approved
        expect(post.reload.hidden).to eq(false)
      end
    end

    describe "#perform_reject_and_delete" do
      it "transitions to the rejected state and deletes the post" do
        result = reviewable.perform admin, :reject_and_delete

        expect(result.transition_to).to eq :rejected
        expect(Post.where(id: post.id).exists?).to eq(false)
      end
    end
    # TODO (reviewable-refresh): Remove the tests above when the legacy combined actions are removed

    context "with new separated actions" do
      before do
        allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
      end

      describe "#perform_delete_post" do
        it "deletes the post and transitions to rejected" do
          result = reviewable.perform admin, :delete_post

          expect(result.transition_to).to eq :rejected
          expect(Post.where(id: post.id).exists?).to eq(false)
        end
      end

      describe "#perform_hide_post" do
        it "hides the post and transitions to rejected" do
          result = reviewable.perform admin, :hide_post

          expect(result.transition_to).to eq :rejected
          expect(post.reload.hidden).to eq(true)
        end
      end

      describe "#perform_unhide_post" do
        it "unhides the post and transitions to approved" do
          post.update!(hidden: true)

          result = reviewable.reload.perform admin, :unhide_post

          expect(result.transition_to).to eq :approved
          expect(post.reload.hidden).to eq(false)
        end
      end

      describe "#perform_no_action_post" do
        it "keeps the post and transitions to ignored" do
          result = reviewable.perform admin, :no_action_post

          expect(result.transition_to).to eq :ignored
          expect(Post.where(id: post.id).exists?).to eq(true)
        end

        it "keeps the post hidden and transitions to ignored" do
          post.update!(hidden: true)

          result = reviewable.reload.perform admin, :no_action_post

          expect(result.transition_to).to eq :ignored
          expect(post.reload.hidden).to eq(true)
        end

        it "keeps the post deleted and transitions to ignored" do
          post.trash!

          result = reviewable.reload.perform admin, :no_action_post

          expect(result.transition_to).to eq :ignored
          expect(Post.where(id: post.id).exists?).to eq(false)
        end
      end

      describe "#perform_restore_post" do
        it "restores the post and transitions to approved" do
          post.trash!

          result = reviewable.reload.perform admin, :restore_post

          expect(result.transition_to).to eq :approved
          expect(Post.where(id: post.id).exists?).to eq(true)
        end
      end

      describe "#perform_edit_post" do
        it "transitions to approved (actual edit is client-side)" do
          result = reviewable.perform admin, :edit_post

          expect(result.transition_to).to eq :approved
        end
      end

      describe "#perform_silence_user" do
        it "transitions to rejected" do
          result = reviewable.perform admin, :silence_user

          expect(result.transition_to).to eq :rejected
        end
      end

      describe "#perform_suspend_user" do
        it "transitions to rejected" do
          result = reviewable.perform admin, :suspend_user

          expect(result.transition_to).to eq :rejected
        end
      end

      describe "#perform_no_action_user" do
        it "transitions to ignored" do
          result = reviewable.perform admin, :no_action_user

          expect(result.transition_to).to eq :ignored
        end
      end
    end
  end
end
