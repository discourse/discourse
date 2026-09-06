# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Nulls
      class First < Nulls
        def expected? = true

        def placement = :first

        def to_sql = " NULLS FIRST"

        def other_end = :last

        def trailing? = false

        def read_first? = true
      end
    end
  end
end
