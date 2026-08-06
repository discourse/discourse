# frozen_string_literal: true

module JsonApiKit
  module Pagination
    # Which way a key is read, and what follows from it: how the ordering names that way, which
    # comparison puts a row after the cursor, what a reversed reading declares instead, and where
    # the database leaves nulls when no placement is named (see Nulls::Undeclared).
    #
    # One case per direction, so nothing has to ask which, and two readings of the same direction
    # are the same value.
    class Direction
      def self.for(direction)
        case direction
        when :asc
          Ascending.new
        when :desc
          Descending.new
        else
          raise ArgumentError, "unknown direction: #{direction}"
        end
      end

      def ==(other) = other.instance_of?(self.class)

      alias eql? ==

      def hash = self.class.hash
    end
  end
end
