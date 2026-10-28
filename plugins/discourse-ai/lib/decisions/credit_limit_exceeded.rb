# frozen_string_literal: true

module DiscourseAi
  module Decisions
    class CreditLimitExceeded < Error
      attr_reader :allocation

      def initialize(message, allocation:)
        super(message)
        @allocation = allocation
      end
    end
  end
end
