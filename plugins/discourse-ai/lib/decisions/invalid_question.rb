# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # A question definition is malformed, usually from admin-supplied configuration.
    class InvalidQuestion < Error
      attr_reader :name, :field

      def initialize(message, name:, field: nil)
        @name = name
        @field = field
        super(message)
      end
    end
  end
end
