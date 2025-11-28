# frozen_string_literal: true

RSpec.describe Reviewable::Actions do
  fab!(:admin)
  fab!(:user)
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:reviewable) do
    ReviewablePost.needs_review!(target: post, created_by: admin, potential_spam: false)
  end

  let(:guardian) { Guardian.new(admin) }
  let(:actions) { described_class.new(reviewable, guardian) }

  describe "Bundle#selected_action" do
    it "returns nil when there are no action logs and no default_action" do
      bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")

      expect(bundle.selected_action).to be_nil
    end

    it "returns the default_action when there are no action logs" do
      bundle =
        actions.add_bundle(
          "#{reviewable.id}-post-actions",
          label: "Post Actions",
          default_action: "no_action_post",
        )

      expect(bundle.selected_action).to eq("no_action_post")
    end

    it "returns the action_key from the most recent action log for the bundle" do
      bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")

      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "hide_post",
        status: :rejected,
        performed_by: admin,
        bundle: "post-actions",
      )

      expect(bundle.selected_action).to eq("hide_post")
    end

    it "returns the action_key from logs even when default_action is set" do
      bundle =
        actions.add_bundle(
          "#{reviewable.id}-post-actions",
          label: "Post Actions",
          default_action: "no_action_post",
        )

      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "hide_post",
        status: :rejected,
        performed_by: admin,
        bundle: "post-actions",
      )

      expect(bundle.selected_action).to eq("hide_post")
    end

    it "returns the most recent action_key when multiple logs exist" do
      bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")

      first_log =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "hide_post",
          status: :rejected,
          performed_by: admin,
          bundle: "post-actions",
        )

      # Ensure the second log has a later timestamp
      sleep 0.01

      second_log =
        ReviewableActionLog.create!(
          reviewable: reviewable,
          action_key: "delete_post",
          status: :rejected,
          performed_by: admin,
          bundle: "post-actions",
        )

      expect(second_log.created_at).to be > first_log.created_at
      expect(bundle.selected_action).to eq("delete_post")
    end

    it "returns only action logs for the matching bundle" do
      post_bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")
      user_bundle = actions.add_bundle("#{reviewable.id}-user-actions", label: "User Actions")

      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "hide_post",
        status: :rejected,
        performed_by: admin,
        bundle: "post-actions",
      )

      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "suspend_user",
        status: :rejected,
        performed_by: admin,
        bundle: "user-actions",
      )

      expect(post_bundle.selected_action).to eq("hide_post")
      expect(user_bundle.selected_action).to eq("suspend_user")
    end

    it "falls back to default_action when no matching logs exist but other logs do" do
      bundle =
        actions.add_bundle(
          "#{reviewable.id}-post-actions",
          label: "Post Actions",
          default_action: "no_action_post",
        )

      # Create a log for a different bundle
      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "suspend_user",
        status: :rejected,
        performed_by: admin,
        bundle: "user-actions",
      )

      expect(bundle.selected_action).to eq("no_action_post")
    end
  end
end
