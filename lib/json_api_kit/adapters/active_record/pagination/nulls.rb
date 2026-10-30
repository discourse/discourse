# frozen_string_literal: true

module JsonApiKit
  module Adapters
    class ActiveRecord < Adapter
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
              raise ArgumentError, "Unknown null placement: #{placement.inspect}."
            end
          end
        end
      end
    end
  end
end
