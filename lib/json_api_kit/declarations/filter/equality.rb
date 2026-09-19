# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filter
      class Equality
        def initialize(name)
          @name = name
        end

        def call(scope, value) = scope.where(name => value)

        private

        attr_reader :name
      end
    end
  end
end
