# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class InputScopeChanges
      Conflict = Class.new(StandardError)

      def initialize(changes)
        @changes = changes.group_by { [it.type, it.collection] }
        @changes.default = [].freeze
      end

      def verify!
        changes
          .detect { |_listing, declarations| declarations.many? }
          .try do |listing, _declarations|
            raise Conflict, "changes the input scope of #{listing.compact.join(" ")} twice."
          end
      end

      def each_for(type, collection = nil, &) = changes[[type, collection]].each(&)

      private

      attr_reader :changes
    end
  end
end
