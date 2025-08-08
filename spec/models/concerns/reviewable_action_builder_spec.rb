# frozen_string_literal: true

require "rails_helper"

RSpec.describe ReviewableActionBuilder do
  let(:admin) { Fabricate(:admin) }
  let(:guardian) { Guardian.new(admin) }
  let(:user) { Fabricate(:user) }
  let(:reviewable) { ReviewableUser.create_for(user) }
  let(:actions) { Reviewable::Actions.new(reviewable, guardian) }

  describe "#build_action" do
    it "adds an action with i18n-derived defaults" do
      reviewable.build_action(actions, :approve_user)

      action = actions.to_a.first
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
      bundle_ids = actions.bundles.map(&:id)
      expect(bundle_ids).to include(action.id)
    end

    it "sets optional fields when provided" do
      reviewable.build_action(
        actions,
        :approve_user,
        icon: "user-plus",
        button_class: "btn-primary",
        client_action: "go",
        confirm: true,
        require_reject_reason: true,
      )

      action = actions.to_a.first
      expect(action.icon).to eq("user-plus")
      expect(action.button_class).to eq("btn-primary")
      expect(action.client_action).to eq("go")
      expect(action.confirm_message).to eq("reviewables.actions.approve_user.confirm")
      expect(action.require_reject_reason).to be(true)
    end

    it "adds the action to the provided bundle" do
      bundle = actions.add_bundle("custom-bundle", icon: "x", label: "Custom")
      reviewable.build_action(actions, :approve_user, bundle: bundle)

      action = actions.to_a.first
      expect(actions.bundles).to include(bundle)
      expect(bundle.actions).to include(action)
    end
  end
end
