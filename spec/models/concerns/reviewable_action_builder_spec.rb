# frozen_string_literal: true

RSpec.describe ReviewableActionBuilder do
  fab!(:admin)
  fab!(:guardian) { Guardian.new(admin) }
  fab!(:user)

  describe "#build_user_actions_bundle" do
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:reviewable_post) do
      ReviewablePost.needs_review!(target: post, created_by: admin, potential_spam: false)
    end
    fab!(:post_actions) { Reviewable::Actions.new(reviewable_post, guardian) }

    it "creates a user bundle with standard actions when allowed" do
      bundle = reviewable_post.build_user_actions_bundle(post_actions, guardian, user)

      # bundle id and label
      expect(bundle.id).to eq("#{reviewable_post.id}-user-actions")
      expect(bundle.label).to eq("reviewables.actions.user_actions.bundle_title")

      # action ids are prefixed with target type (post-...)
      action_ids = bundle.actions.map(&:id)
      expect(action_ids).to include("post-no_action_user")
      expect(action_ids).to include("post-silence_user")
      expect(action_ids).to include("post-suspend_user")
      expect(action_ids).to include("post-delete_user")
      expect(action_ids).to include("post-delete_and_block_user")

      # client_action is set for moderation actions
      silence = bundle.actions.find { |a| a.id == "post-silence_user" }
      suspend = bundle.actions.find { |a| a.id == "post-suspend_user" }
      expect(silence.client_action).to eq("silence")
      expect(suspend.client_action).to eq("suspend")
    end

    it "includes only the no-op action when user is nil" do
      bundle = reviewable_post.build_user_actions_bundle(post_actions, guardian, nil)
      server_actions = bundle.actions.map(&:server_action)
      expect(server_actions).to include("no_action_user")
      expect(server_actions - ["no_action_user"]).to be_empty
    end
  end

  describe "permission helpers" do
    fab!(:post) { Fabricate(:post, user: user) }
    fab!(:reviewable_post) do
      ReviewablePost.needs_review!(target: post, created_by: admin, potential_spam: false)
    end
    fab!(:post_actions) { Reviewable::Actions.new(reviewable_post, guardian) }

    it "allows admin to suspend and delete" do
      expect(reviewable_post.allow_user_suspend_actions?(guardian, user)).to be(true)
      expect(reviewable_post.allow_user_delete_actions?(guardian, user)).to be(true)
    end

    it "disallows regular user to suspend and delete" do
      regular_guardian = Guardian.new(Fabricate(:user))
      expect(reviewable_post.allow_user_suspend_actions?(regular_guardian, user)).to be(false)
      expect(reviewable_post.allow_user_delete_actions?(regular_guardian, user)).to be(false)
    end

    describe "overriding" do
      it "removes suspend/delete actions when overridden to false even for admin" do
        allow_any_instance_of(ReviewablePost).to receive(:allow_user_suspend_actions?).and_return(
          false,
        )
        allow_any_instance_of(ReviewablePost).to receive(:allow_user_delete_actions?).and_return(
          false,
        )
        bundle = reviewable_post.build_user_actions_bundle(post_actions, guardian, user)

        server_actions = bundle.actions.map(&:server_action)
        expect(server_actions).to include("no_action_user")
        expect(server_actions).not_to include(
          "silence_user",
          "suspend_user",
          "delete_user",
          "delete_and_block_user",
        )
      end

      it "adds suspend/delete actions when overridden to true even for regular user" do
        regular_guardian = Guardian.new(Fabricate(:user))
        allow_any_instance_of(ReviewablePost).to receive(:allow_user_suspend_actions?).and_return(
          true,
        )
        allow_any_instance_of(ReviewablePost).to receive(:allow_user_delete_actions?).and_return(
          true,
        )
        actions = Reviewable::Actions.new(reviewable_post, regular_guardian)
        bundle = reviewable_post.build_user_actions_bundle(actions, regular_guardian, user)

        server_actions = bundle.actions.map(&:server_action)
        expect(server_actions).to include(
          "no_action_user",
          "silence_user",
          "suspend_user",
          "delete_user",
          "delete_and_block_user",
        )
      end
    end
  end

  describe "#build_action" do
    fab!(:reviewable_user) { ReviewableUser.create_for(user) }

    it "adds an action with i18n-derived defaults" do
      user_actions = Reviewable::Actions.new(reviewable_user, guardian)

      reviewable_user.build_action(user_actions, :approve_user)

      action = user_actions.to_a.first
      expect(action).to be_present
      expect(action.label).to eq("reviewables.actions.approve_user.title")
      expect(action.description).to eq("reviewables.actions.approve_user.description")
      expect(action.completed_message).to eq("reviewables.actions.approve_user.complete")
      expect(action.confirm_message).to be_nil
      expect(action.icon).to be_nil
      expect(action.button_class).to be_nil
      expect(action.client_action).to be_nil
      expect(action.require_reject_reason).to be(false)

      # It should attach to a bundle automatically matching the full action id
      bundle_ids = user_actions.bundles.map(&:id)
      expect(bundle_ids).to include(action.id)
    end

    it "sets optional fields when provided" do
      user_actions = Reviewable::Actions.new(reviewable_user, guardian)

      reviewable_user.build_action(
        user_actions,
        :approve_user,
        icon: "user-plus",
        button_class: "btn-primary",
        client_action: "go",
        confirm: true,
        require_reject_reason: true,
      )

      action = user_actions.to_a.first
      expect(action.icon).to eq("user-plus")
      expect(action.button_class).to eq("btn-primary")
      expect(action.client_action).to eq("go")
      expect(action.confirm_message).to eq("reviewables.actions.approve_user.confirm")
      expect(action.require_reject_reason).to be(true)
    end

    it "adds the action to the provided bundle" do
      user_actions = Reviewable::Actions.new(reviewable_user, guardian)

      bundle = user_actions.add_bundle("custom-bundle", icon: "x", label: "Custom")
      reviewable_user.build_action(user_actions, :approve_user, bundle: bundle)

      action = user_actions.to_a.first
      expect(user_actions.bundles).to include(bundle)
      expect(bundle.actions).to include(action)
    end
  end
end
