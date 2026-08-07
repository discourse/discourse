# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Direction
      # Read from the largest value downwards, where a row follows the cursor by being smaller,
      # and where the database leaves nulls at the head of the reading.
      class Descending < Direction
        def to_sym = :desc

        def to_sql = "DESC"

        def operator = "<"

        def reversed = :asc

        def nulls_first? = true
      end
    end
  end
end
