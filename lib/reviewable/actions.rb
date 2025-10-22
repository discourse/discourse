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
    end

    class Action < Item
      attr_accessor :icon,
                    :button_class,
                    :label,
                    :description,
                    :confirm_message,
                    :client_action,
                    :require_reject_reason,
                    :custom_modal,
                    :completed_message

      def initialize(id, icon = nil, button_class = nil, label = nil)
        super(id)
        @icon, @button_class, @label = icon, button_class, label
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

    def add(id, bundle: nil)
      id = [reviewable.target_type&.underscore, id].compact_blank.join("-")
      action = Actions.common_actions[id] || Action.new(id)
      yield action if block_given?
      @content << action

      bundle ||= add_bundle(id)
      bundle.actions << action
    end
  end
end
