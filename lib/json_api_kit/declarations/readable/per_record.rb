# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Readable
      class PerRecord < Readable
        def per_record? = true

        def readable_by?(_guardian) = true

        def readable_for?(guardian, record) = rule.call(guardian, record)
      end
    end
  end
end
