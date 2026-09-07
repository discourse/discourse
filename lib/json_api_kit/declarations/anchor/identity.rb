# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Anchor
      class Identity
        def initialize(name, value)
          @name = name
          @value = value
        end

        def locate(scope, order:)
          order.locate(scope.where(scope.primary_key => value)) or raise NoRow.new(name, value)
        end

        private

        attr_reader :name, :value
      end
    end
  end
end
