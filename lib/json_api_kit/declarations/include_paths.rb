# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class IncludePaths
      Unresolved = Class.new(StandardError)

      def initialize(deep_paths, relationships:)
        @deep_paths = Paths.new(deep_paths)
        @relationships = relationships
        refuse_unresolved
      end

      def allow(paths)
        refuse_unknown(paths)
        paths
      end

      def include?(path) = path.entered? || allowed_paths.include?(path)

      private

      attr_reader :deep_paths, :relationships

      def refuse_unknown(paths)
        unknown_paths = paths.reject { include?(it) }
        return if unknown_paths.empty?
        raise KeyError, "There is no relationship path named #{unknown_paths.join(", ")}."
      end

      def allowed_paths = @allowed_paths ||= relationships.paths + deep_paths

      def refuse_unresolved
        unresolved_paths = deep_paths.reject { relationships.resolves?(it) }
        return if unresolved_paths.empty?
        raise Unresolved, "#{unresolved_paths.join(", ")} reads a relationship nobody declares"
      end
    end
  end
end
