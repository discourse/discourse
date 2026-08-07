# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # Where a key's nulls sort, and what follows from it: how the ordering names that end, what a
    # reversed reading declares instead, which band of a split listing is read first, and whether
    # a comparison has to take the null rows in rather than compare them.
    #
    # One case per reading, so nothing asks which: a placement declared at either end, and no
    # placement at all — a key expecting no nulls, either because none were declared or because
    # the band it reads has values in every row (see Undeclared).
    class Nulls
      def self.for(placement, direction:)
        case placement
        when nil
          Undeclared.new(direction)
        when :last
          Last.new
        when :first
          First.new
        else
          raise ArgumentError, "unknown nulls: #{placement}"
        end
      end
    end
  end
end
