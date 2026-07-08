# frozen_string_literal: true

module DiscourseDataExplorer
  module JsonApiKit
    # The ordered set of VersionChanges, anchored on the API's initial version.
    # Resolves a client-supplied date to a known version (Stripe-style snap-down)
    # and computes the gap — the chain of changes separating a resolved version
    # from latest. See docs/versioning-design.md.
    class VersionRegistry
      Error = Class.new(StandardError)
      MissingVersion = Class.new(Error)
      FutureVersion = Class.new(Error)
      UnknownVersion = Class.new(Error)

      attr_reader :initial_version

      def initialize(initial_version:)
        @initial_version = ApiVersion.parse(initial_version)
        @changes = []
      end

      def register(change_class)
        if change_class.version.nil? || change_class.description.blank?
          raise ArgumentError, "#{change_class} must declare `version` and `description`"
        end
        if change_class.version <= initial_version
          raise ArgumentError,
                "#{change_class} (#{change_class.version}) predates the initial version (#{initial_version})"
        end
        @changes << change_class
        change_class
      end

      # Oldest→newest; same-date changes keep registration order.
      def changes = @changes.sort_by.with_index { |change, index| [change.version, index] }

      def versions = ([initial_version] + @changes.map(&:version)).uniq.sort

      def current_version = versions.last

      def resolve(value, today: Date.current)
        raise MissingVersion if value.blank?

        requested = ApiVersion.parse(value)
        if requested.future?(today:)
          raise FutureVersion, "#{requested} is in the future — pin a current date"
        end
        if requested < initial_version
          raise UnknownVersion, "#{requested} predates the first API version (#{initial_version})"
        end

        versions.reverse_each.find { it <= requested }
      end

      # The changes separating `version` from latest, newest→oldest — the
      # response-down application order (reverse it for request-up).
      def gap_for(version) = changes.select { it.version > version }.reverse
    end
  end
end
