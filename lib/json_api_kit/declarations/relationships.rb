# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationships
      delegate :fetch, to: :relationships
      delegate :keys, :values, :slice, to: :relationships, private: true

      def initialize(relationships)
        @relationships = relationships.index_by(&:name)
      end

      def pick(names) = slice(*names).values

      def names = keys

      def parameter_names = values.map(&:parameter_name)

      def for_parameter(name) = values.detect { it.parameter_name == name.to_s }

      def paths = Paths.new(names)

      def resolves?(path)
        relationship = fetch(path.current, nil)
        return false unless relationship
        return true if path.last?
        relationship.resolves?(path.next)
      end

      private

      attr_reader :relationships
    end
  end
end
