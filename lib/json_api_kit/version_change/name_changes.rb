# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class NameChanges
      Conflict = Class.new(StandardError)
      PASS_THROUGH = ->(_index, name) { PassThrough.new(name) }

      def initialize(changes)
        @changes = changes.dup
        @upward = index_by(&:previous_names)
        @downward = index_by(&:current_names)
      end

      def current_names(name) = upward[name].current_names

      def previous_names(name) = downward[name].previous_names

      def affects?(name) = upward.key?(name)

      def verify!
        duplicate_name(&:previous_names).try { raise Conflict, "changes #{it} twice." }
        duplicate_name(&:current_names).try { raise Conflict, "changes two names into #{it}." }
      end

      private

      attr_reader :changes, :upward, :downward

      def current_changes(names) = names.map { upward[it] }.uniq

      def previous_changes(names) = names.map { downward[it] }.uniq

      def index_by(&names)
        changes
          .flat_map { |change| names.call(change).map { [it, change] } }
          .to_h
          .tap { it.default_proc = PASS_THROUGH }
      end

      def duplicate_name(&)
        changes.flat_map(&).tally.detect { |_name, count| count > 1 }&.first
      end
    end
  end
end
