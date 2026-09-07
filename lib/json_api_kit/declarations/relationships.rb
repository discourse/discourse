# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationships
      def initialize(relationships)
        @relationships = relationships.index_by(&:name)
      end

      def pick(names) = relationships.slice(*names).values

      def names = relationships.keys

      def paths = Paths.new(names)

      def resolves?(path)
        relationship = relationships[path.current]
        return false unless relationship
        return true if path.last?
        relationship.resolves?(path.next)
      end

      private

      attr_reader :relationships
    end
  end
end
