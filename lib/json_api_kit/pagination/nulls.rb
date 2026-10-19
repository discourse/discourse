# frozen_string_literal: true

module JsonApiKit
  module Pagination
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
