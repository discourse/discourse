# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class DefaultSorts
      Conflict = Class.new(StandardError)

      def initialize(defaults)
        @defaults = defaults.group_by(&:type)
        @defaults.default = [].freeze
      end

      def verify!
        defaults
          .detect { |_type, declarations| declarations.many? }
          .try do |type, _declarations|
            raise Conflict, "changes the default sort for #{type} twice."
          end
      end

      def each_for(type, &) = defaults[type].each(&)

      private

      attr_reader :defaults
    end
  end
end
