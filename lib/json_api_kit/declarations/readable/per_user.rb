# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Readable
      class PerUser < Readable
        def per_record? = false

        def readable_by?(guardian) = rule.call(guardian)

        def readable_for?(_guardian, _record) = true
      end
    end
  end
end
