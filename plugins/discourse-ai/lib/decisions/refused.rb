# frozen_string_literal: true

module DiscourseAi
  module Decisions
    # Raised when reading a value from an answer the model refused to give.
    class Refused < Error
      attr_reader :name

      def initialize(name)
        @name = name
        super("The model refused to answer #{name}")
      end
    end
  end
end
