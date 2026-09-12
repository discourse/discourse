# frozen_string_literal: true

module JsonApiKit
  class Glossary
    class VersionRule
      def initialize(version)
        @changes = VersionChange.after(version)
      end

      def declared_attributes(attributes)
        changes
          .each_with_index
          .reduce(attributes) do |result, (change, index)|
            change.current_attributes(result)
          rescue VersionChange::Converter::Failure => failure
            raise failure.convert_names { member_names(it, changes: changes.take(index)) }
          end
      end

      def declared_name(name)
        current_name(name).tap { raise Correction.new(it) if member_names(it).exclude?(name) }
      end

      def member_name(name)
        changes.reverse_each.reduce(name) { |result, change| change.previous(result) }
      end

      def member_attributes(attributes)
        changes
          .reverse_each
          .reduce(attributes) { |result, change| change.previous_attributes(result) }
      end

      private

      attr_reader :changes

      def current_name(name) = changes.reduce(name) { |result, change| change.current(result) }

      def member_names(name, changes: self.changes)
        changes
          .reverse_each
          .reduce([name]) { |names, change| names.flat_map { change.previous_names(it) } }
      end
    end
  end
end
