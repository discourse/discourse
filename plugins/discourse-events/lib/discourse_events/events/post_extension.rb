# frozen_string_literal: true

module DiscourseEvents
  module Events
    module PostExtension
      extend ActiveSupport::Concern

      # Used only by trusted automatic Event archival.
      # Does not change post editing or rendering attribution.
      attr_accessor :event_rollover_validation_actor

      prepended do
        has_one :event,
                dependent: :destroy,
                class_name: "DiscourseEvents::Events::Event",
                foreign_key: :id

        validate :valid_event
      end

      def valid_event
        return unless raw_changed?

        validator =
          DiscourseEvents::Events::Validator.new(
            self,
            authorization_user: event_rollover_validation_actor,
          )
        validator.validate_event
      end
    end
  end
end
