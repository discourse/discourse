# frozen_string_literal: true

RSpec.describe ReviewableBundledActionSerializer do
  fab!(:admin)
  fab!(:user)
  fab!(:post) { Fabricate(:post, user: user) }
  fab!(:reviewable) do
    ReviewablePost.needs_review!(target: post, created_by: admin, potential_spam: false)
  end

  let(:guardian) { Guardian.new(admin) }
  let(:actions) { Reviewable::Actions.new(reviewable, guardian) }

  describe "#selected_action" do
    it "is not included when there are no action logs and no default_action" do
      bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")
      serializer = described_class.new(bundle, scope: guardian, root: nil)
      json = serializer.as_json

      expect(json[:selected_action]).to be_nil
      expect(json.key?(:selected_action)).to be false
    end

    it "includes default_action when there are no action logs" do
      bundle =
        actions.add_bundle(
          "#{reviewable.id}-post-actions",
          label: "Post Actions",
          default_action: "no_action_post",
        )
      serializer = described_class.new(bundle, scope: guardian, root: nil)
      json = serializer.as_json

      expect(json[:selected_action]).to eq("no_action_post")
    end

    it "includes selected_action when an action log exists" do
      bundle = actions.add_bundle("#{reviewable.id}-post-actions", label: "Post Actions")

      ReviewableActionLog.create!(
        reviewable: reviewable,
        action_key: "hide_post",
        status: :rejected,
        performed_by: admin,
        bundle: "post-actions",
      )

      serializer = described_class.new(bundle, scope: guardian, root: nil)
      json = serializer.as_json

      expect(json[:selected_action]).to eq("hide_post")
    end

    it "includes the most recent action_key when multiple logs exist" do
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

      serializer = described_class.new(bundle, scope: guardian, root: nil)
      json = serializer.as_json

      expect(json[:selected_action]).to eq("delete_post")
    end
  end
end
