# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Filter
      # The condition a filter puts on a listing when its declaration names nothing else: the rows
      # whose column holds the value, or any of a list of them — `filter[id]=1,2` asks for both.
      #
      # Equality is what a filter means unless a resource says otherwise, and it is the shape an
      # index can serve; anything looser is a declaration a resource makes on purpose.
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
