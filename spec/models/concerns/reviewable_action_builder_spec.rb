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

    before do
      reviewable_post.instance_variable_set(:@actions, post_actions)
      reviewable_post.instance_variable_set(:@guardian, guardian)
      reviewable_post.instance_variable_set(:@action_args, {})
    end

    it "creates a user bundle with standard actions when allowed" do
      bundle = reviewable_post.build_user_actions_bundle

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
      allow(reviewable_post).to receive(:target_created_by).and_return(nil)

      bundle = reviewable_post.build_user_actions_bundle
      server_actions = bundle.actions.map(&:server_action)

      expect(server_actions).to include("no_action_user")
      expect(server_actions - ["no_action_user"]).to be_empty
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

  describe "#calculate_final_status_from_logs" do
    fab!(:moderator)
    fab!(:reviewable, :reviewable_flagged_post)

    it "returns ignored when all logs are ignored" do
      reviewable.reviewable_action_logs.create!(
        action_key: "ignore_and_do_nothing",
        status: :ignored,
        performed_by: moderator,
        bundle: "post-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "no_action_user",
        status: :ignored,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable.calculate_final_status_from_logs).to eq(:ignored)
    end

    it "returns rejected when all logs are rejected" do
      reviewable.reviewable_action_logs.create!(
        action_key: "hide_post",
        status: :rejected,
        performed_by: moderator,
        bundle: "post-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "suspend_user",
        status: :rejected,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable.calculate_final_status_from_logs).to eq(:rejected)
    end

    it "returns approved when any log is approved" do
      reviewable.reviewable_action_logs.create!(
        action_key: "agree_and_keep",
        status: :approved,
        performed_by: moderator,
        bundle: "legacy-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "suspend_user",
        status: :rejected,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable.calculate_final_status_from_logs).to eq(:approved)
    end

    it "returns pending for mixed rejected and ignored statuses" do
      reviewable.reviewable_action_logs.create!(
        action_key: "hide_post",
        status: :rejected,
        performed_by: moderator,
        bundle: "post-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "no_action_user",
        status: :ignored,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable.calculate_final_status_from_logs).to eq(:pending)
    end

    it "returns pending when no logs exist" do
      expect(reviewable.calculate_final_status_from_logs).to eq(:pending)
    end
  end

  describe "#all_bundles_actioned?" do
    fab!(:moderator)
    fab!(:reviewable, :reviewable_flagged_post)

    before do
      SiteSetting.reviewable_old_moderator_actions = false
      allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
    end

    it "returns true when all bundles have at least one action logged" do
      reviewable.reviewable_action_logs.create!(
        action_key: "edit_post",
        status: :approved,
        performed_by: moderator,
        bundle: "post-actions",
      )
      reviewable.reviewable_action_logs.create!(
        action_key: "suspend_user",
        status: :rejected,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable.all_bundles_actioned?(guardian)).to be true
    end

    it "returns false when not all bundles have been actioned" do
      reviewable.reviewable_action_logs.create!(
        action_key: "edit_post",
        status: :approved,
        performed_by: moderator,
        bundle: "post-actions",
      )

      expect(reviewable.all_bundles_actioned?(guardian)).to be false
    end

    it "returns true for reviewable with single bundle when that bundle is actioned" do
      reviewable_user = ReviewableUser.create_for(user)
      reviewable_user.reviewable_action_logs.create!(
        action_key: "approve_user",
        status: :approved,
        performed_by: moderator,
        bundle: "user-actions",
      )

      expect(reviewable_user.all_bundles_actioned?(guardian)).to be true
    end

    it "returns false when no actions have been logged" do
      expect(reviewable.all_bundles_actioned?(guardian)).to be false
    end
  end

  describe "#perform with action logging" do
    fab!(:moderator)
    fab!(:reviewable, :reviewable_flagged_post)

    context "with new UI enabled" do
      before do
        SiteSetting.reviewable_old_moderator_actions = false
        allow_any_instance_of(Guardian).to receive(:can_see_reviewable_ui_refresh?).and_return(true)
      end

      it "creates an action log" do
        expect { reviewable.perform(moderator, :edit_post, guardian: guardian) }.to change {
          reviewable.reviewable_action_logs.count
        }.by(1)

        log = reviewable.reviewable_action_logs.last
        expect(log.action_key).to eq("edit_post")
        expect(log.status).to eq("approved")
        expect(log.performed_by).to eq(moderator)
      end

      it "keeps reviewable pending when not all bundles are actioned" do
        reviewable.perform(moderator, :edit_post, guardian: guardian)

        reviewable.reload
        expect(reviewable.status).to eq("pending")
        expect(reviewable.reviewable_action_logs.count).to eq(1)
      end

      it "finalizes status when all bundles are actioned" do
        reviewable.perform(moderator, :edit_post, guardian: guardian)
        expect(reviewable.reload.status).to eq("pending")
        reviewable.perform(moderator, :suspend_user, guardian: guardian)

        reviewable.reload
        expect(reviewable.status).to eq("approved")
        expect(reviewable.reviewable_action_logs.count).to eq(2)
      end

      it "calculates correct final status for all ignored" do
        reviewable.perform(moderator, :no_action_post, guardian: guardian)
        reviewable.perform(moderator, :no_action_user, guardian: guardian)

        reviewable.reload
        expect(reviewable.status).to eq("ignored")
      end

      it "calculates correct final status for all rejected" do
        reviewable.perform(moderator, :hide_post, guardian: guardian)
        reviewable.perform(moderator, :silence_user, guardian: guardian)

        reviewable.reload
        expect(reviewable.status).to eq("rejected")
      end
    end

    context "with old UI (backward compatibility)" do
      before { SiteSetting.reviewable_old_moderator_actions = true }

      it "creates an action log" do
        expect { reviewable.perform(moderator, :agree_and_keep, guardian: guardian) }.to change {
          reviewable.reviewable_action_logs.count
        }.by(1)
      end

      it "transitions immediately (original behavior)" do
        reviewable.perform(moderator, :agree_and_keep, guardian: guardian)

        reviewable.reload
        expect(reviewable.status).to eq("approved")
      end
    end
  end
end
