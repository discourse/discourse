# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Direction
      class Descending < Direction
        def to_sym = :desc

        def to_sql = "DESC"

        def operator = "<"

        def other_way = :asc

        def nulls_first? = true
      end
    end
  end
end
