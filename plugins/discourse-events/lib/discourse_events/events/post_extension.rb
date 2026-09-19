# frozen_string_literal: true

module DiscourseEvents
  module Events
    module PostExtension
      extend ActiveSupport::Concern

      prepended do
        has_one :event,
                dependent: :destroy,
                class_name: "DiscourseEvents::Events::Event",
                foreign_key: :id

        validate :valid_event
      end

      def valid_event
        return unless raw_changed?

        validator = DiscourseEvents::Events::Validator.new(self)
        validator.validate_event
      end
    end
  end
end
