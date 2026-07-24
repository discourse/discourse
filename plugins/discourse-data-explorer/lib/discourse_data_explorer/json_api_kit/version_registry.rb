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
      UnknownComponent = Class.new(Error)
      NotOverridable = Class.new(Error)

      attr_reader :initial_version

      def initialize(initial_version:)
        @initial_version = ApiVersion.parse(initial_version)
        @changes = {}
      end

      # Core-owned changes register with no owner; an extension's changes carry
      # its namespace. Owners have disjoint timelines: only core changes form the
      # base snap set, and each owner's changes can be governed by an override.
      def register(change_class, owner: nil)
        if change_class.version.nil? || change_class.description.blank?
          raise ArgumentError, "#{change_class} must declare `version` and `description`"
        end
        if change_class.version <= initial_version
          raise ArgumentError,
                "#{change_class} (#{change_class.version}) predates the initial version (#{initial_version})"
        end
        @changes[change_class] = owner
        change_class
      end

      # Extensions come and go with their owner (plugin enabled/disabled); their
      # changes leave the timeline with them. Core changes are never unregistered.
      def unregister(change_class) = @changes.delete(change_class)

      # Oldest→newest; same-date changes keep registration order.
      def changes = @changes.keys.sort_by.with_index { |change, index| [change.version, index] }

      # The base snap set is CORE's timeline only: a resolved base date always
      # reads against one public changelog, and one owner's movement can never
      # push a pin past another owner's future changes.
      def versions
        core_versions = @changes.filter_map { |change, owner| change.version if owner.nil? }
        ([initial_version] + core_versions).uniq.sort
      end

      def current_version = versions.last

      def resolve(value, today: Date.current)
        raise MissingVersion if value.blank?
        snap(versions, ApiVersion.parse(value), today:)
      end

      # Override resolution: snap against one owner's own timeline (anchored on
      # the initial version, mirroring the base).
      def resolve_for(owner, value, today: Date.current)
        owned =
          @changes.filter_map { |change, change_owner| change.version if change_owner == owner }
        snap(([initial_version] + owned).uniq.sort, ApiVersion.parse(value), today:)
      end

      # The changes separating each owner's effective date from latest,
      # newest→oldest — the response-down application order (reverse it for
      # request-up). An owner named in `overrides` is governed by its own date;
      # everything else by `version`.
      def gap_for(version, overrides: {})
        changes.select { it.version > (overrides[@changes[it]] || version) }.reverse
      end

      # The newest removal wins if an endpoint were ever removed twice.
      # `controller` is the route-dialect path string (Controller#controller_path).
      def endpoint_removal(controller, action)
        changes.reverse_each do |change|
          entry =
            change.removed_endpoints.find do
              it[:controller] == controller.to_s && it[:action] == action.to_sym
            end
          return entry.merge(change:) if entry
        end
        nil
      end

      private

      def snap(snap_set, requested, today:)
        if requested.future?(today:)
          raise FutureVersion, "#{requested} is in the future — pin a current date"
        end
        if requested < initial_version
          raise UnknownVersion, "#{requested} predates the first API version (#{initial_version})"
        end

        snap_set.reverse_each.find { it <= requested }
      end
    end
  end
end
