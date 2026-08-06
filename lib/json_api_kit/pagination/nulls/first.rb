# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      # Nulls at the head of the reading: the band a listing opens with, so every row that has a
      # value follows one, and a comparison against a value leaves them behind.
      class First < Nulls
        def expected? = true

        def placement = :first

        def to_sql = " NULLS FIRST"

        def reversed = :last

        def trailing? = false

        def read_first? = true
      end
    end
  end
end
