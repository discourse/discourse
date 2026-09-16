# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class DefaultSorts
      Conflict = Class.new(StandardError)

      def initialize(defaults)
        @defaults = defaults.dup
      end

      def verify!
        defaults
          .map(&:type)
          .tally
          .detect { |_type, count| count > 1 }
          .try { |type, _count| raise Conflict, "changes the default sort for #{type} twice." }
      end

      def convert_names(&) = defaults.map { it.convert_names(&) }

      private

      attr_reader :defaults
    end
  end
end
