# frozen_string_literal: true

module JsonApiKit
  class Glossary
    class VersionRule
      def initialize(version)
        @changes = VersionChange.after(version)
      end

      def declared_name(name)
        current_name(name).tap { raise Correction.new(it) unless member_name(it) == name }
      end

      def member_name(name)
        changes.reverse_each.reduce(name) { |result, change| change.previous(result) }
      end

      private

      attr_reader :changes

      def current_name(name) = changes.reduce(name) { |result, change| change.current(result) }
    end
  end
end
