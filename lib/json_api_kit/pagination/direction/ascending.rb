# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Direction
      # Read from the smallest value upwards, where a row follows the cursor by being greater.
      class Ascending < Direction
        def to_sym = :asc

        def to_sql = "ASC"

        def operator = ">"

        def reversed = :desc

        def nulls_first? = false
      end
    end
  end
end
