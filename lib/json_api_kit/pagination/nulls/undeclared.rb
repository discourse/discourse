# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      # No placement, and so no nulls looked for: either none were declared, or the band being
      # read has a value in every row. The ordering names no end, which is what lets an ordinary
      # index serve the reading; should a null turn up regardless, the database's own placement
      # is the one that applies — nulls last ascending, nulls first descending.
      class Undeclared < Nulls
        def initialize(direction)
          @direction = direction
        end

        def expected? = false

        def placement = nil

        def to_sql = ""

        def reversed = nil

        def trailing? = false

        def read_first? = direction.nulls_first?

        private

        attr_reader :direction
      end
    end
  end
end
