# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Direction
      class Ascending < Direction
        def to_sym = :asc

        def to_sql = "ASC"

        def operator = ">"

        def other_way = :desc

        def nulls_first? = false
      end
    end
  end
end
