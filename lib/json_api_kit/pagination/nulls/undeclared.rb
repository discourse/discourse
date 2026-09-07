# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      class Undeclared < Nulls
        def initialize(direction)
          @direction = direction
        end

        def expected? = false

        def placement = nil

        def to_sql = ""

        def other_end = nil

        def trailing? = false

        def read_first? = direction.nulls_first?

        private

        attr_reader :direction
      end
    end
  end
end
