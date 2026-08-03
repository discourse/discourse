# frozen_string_literal: true

module JsonApiKit
  module Pagination
    class Direction
      def self.for(direction)
        case direction.to_s
        when "asc"
          Ascending.new
        when "desc"
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
