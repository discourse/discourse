# frozen_string_literal: true

require "reviewable/collection"

class Reviewable < ActiveRecord::Base
  class Actions < Reviewable::Collection
    attr_reader :bundles, :reviewable

    def initialize(reviewable, guardian, args = nil)
      super(reviewable, guardian, args)
      @bundles = []
    end

    # Add common actions here to make them easier for reviewables to re-use. If it's a
    # one off, add it manually.
    def self.common_actions
      {
        approve: Action.new(:approve, "thumbs-up", "reviewables.actions.approve.title"),
        reject: Action.new(:reject, "thumbs-down", "reviewables.actions.reject.title"),
        delete: Action.new(:delete, "trash-can", "reviewables.actions.delete.title"),
      }
    end

    class Bundle < Item
      attr_accessor :icon, :label, :actions, :secondary

      # A secondary bundle holds actions that don't resolve the reviewable, so
      # the client lists them apart from the answers to its context question.
      def initialize(id, icon: nil, label: nil, secondary: false)
        super(id)
        @icon = icon
        @label = label
        @secondary = secondary
        @actions = []
      end

      def empty?
        @actions.empty?
      end

      def bundle_id
        id.split("-", 2).last
      end
    end

    class Action < Item
      attr_accessor :icon,
                    :button_class,
                    :label,
                    :description,
                    :confirm_message,
                    :confirm_message_args,
                    :confirm_destructive,
                    :client_action,
                    :require_reject_reason,
                    :custom_modal,
                    :completed_message,
                    :penalty_effect

      def initialize(id, icon = nil, button_class = nil, label = nil)
        super(id)
        @icon, @button_class, @label = icon, button_class, label
      end

      # The id without its reviewable prefix, e.g. "post-delete_user", so the
      # client can key styling and selection on something stable. Must not end
      # in `_id`: the client store reads such attributes as record references.
      def action_name
        id.split("-", 2).last
      end

      def server_action
        id.split("-").last
      end
    end

    def add_bundle(id, icon: nil, label: nil, secondary: false)
      bundle = Bundle.new(id, icon:, label:, secondary:)
      @bundles << bundle
      bundle
    end

    # Ids are scoped to the reviewable because actions serialize into one
    # id-keyed collection for the whole queue. Two reviewables offering the same
    # action would otherwise collapse into a single record, and every one of
    # them would render the last copy. Bundle ids are scoped by their callers.
    def add(id, bundle: nil, secondary: false)
      action_name = [reviewable.target_type&.underscore, id].compact_blank.join("-")
      scoped_id = [reviewable.id, action_name].compact_blank.join("-")
      action = Actions.common_actions[action_name] || Action.new(scoped_id)
      yield action if block_given?
      @content << action

      bundle ||= add_bundle(scoped_id, secondary:)
      bundle.actions << action
    end
  end
end
