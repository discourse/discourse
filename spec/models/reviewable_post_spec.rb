# frozen_string_literal: true

RSpec.describe ReviewablePost do
  fab!(:admin)

  describe "#build_actions" do
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
  end

  describe "Performing actions" do
    let(:post) { Fabricate(:post) }
    let(:reviewable) { ReviewablePost.needs_review!(target: post, created_by: admin) }

    before { reviewable.created_new! }

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
  end
end
