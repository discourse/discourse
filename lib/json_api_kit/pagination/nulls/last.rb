# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      # Nulls at the end of the reading: the band a listing trails off into, and the rows a
      # comparison against any value has to take in, every comparison against NULL being NULL.
      class Last < Nulls
        def expected? = true

        def placement = :last

        def to_sql = " NULLS LAST"

        def reversed = :first

        def trailing? = true

        def read_first? = false
      end
    end
  end
end
