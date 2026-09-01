# frozen_string_literal: true

require "reviewable/collection"

class Reviewable < ActiveRecord::Base
  class Actions < Reviewable::Collection
    attr_reader :bundles, :reviewable

    # Add common actions here to make them easier for reviewables to re-use. If it's a
    # one off, add it manually.
    class << self
      def common_actions
        {
          approve: Action.new(:approve, "thumbs-up", "reviewables.actions.approve.title"),
          reject: Action.new(:reject, "thumbs-down", "reviewables.actions.reject.title"),
          delete: Action.new(:delete, "trash-can", "reviewables.actions.delete.title"),
        }
      end
    end

    def initialize(reviewable, guardian, args = nil)
      super(reviewable, guardian, args)
      @bundles = []
    end

    class Bundle < Item
      attr_accessor :icon, :label, :actions

      def initialize(id, icon: nil, label: nil)
        super(id)
        @icon = icon
        @label = label
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
                    :completed_message

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

    def add_bundle(id, icon: nil, label: nil)
      bundle = Bundle.new(id, icon: icon, label: label)
      @bundles << bundle
      bundle
    end

    # Ids are scoped to the reviewable because actions serialize into one
    # id-keyed collection for the whole queue. Two reviewables offering the same
    # action would otherwise collapse into a single record, and every one of
    # them would render the last copy. Bundle ids are scoped by their callers.
    def add(id, bundle: nil)
      action_name = [reviewable.target_type&.underscore, id].compact_blank.join("-")
      scoped_id = [reviewable.id, action_name].compact_blank.join("-")
      action = Actions.common_actions[action_name] || Action.new(scoped_id)
      yield action if block_given?
      @content << action

      bundle ||= add_bundle(scoped_id)
      bundle.actions << action
    end
  end
end
