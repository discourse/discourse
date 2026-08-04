# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Keyset
      # The 0/1 helper that sends a nullable key's NULLs to the end of the order and
      # keeps them reachable by a cursor. It is a key like any other — projected,
      # ordered, read off a record — which is what lets the rest of the keyset stay
      # ignorant of nullability.
      #
      # Its SQL comes from the flagged key's SQL, never from that key's alias: an alias
      # cannot be referenced by the SELECT that defines it.
      class NullFlag < Key
        def initialize(source, direction: :asc)
          @source = source
          super(:"#{source.name}_is_null", direction:)
        end

        def projected? = true

        def reverse = self.class.new(source, direction: opposite)

        def value_for(record) = source.value_for(record).nil? ? 1 : 0

        def value_sql(model) = "CASE WHEN #{source.value_sql(model)} IS NULL THEN 1 ELSE 0 END"

        private

        attr_reader :source
      end
    end
  end
end
