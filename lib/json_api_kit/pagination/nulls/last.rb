# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      class Last < Nulls
        def expected? = true

        def placement = :last

        def to_sql = " NULLS LAST"

        def other_end = :first

        def trailing? = true

        def read_first? = false
      end
    end
  end
end
