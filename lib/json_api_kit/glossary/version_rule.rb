# frozen_string_literal: true

module JsonApiKit
  class Glossary
    class VersionRule
      def initialize(changes)
        @changes = changes
      end

      def declared_attributes(attributes, existing: ExistingValues::None)
        changes
          .each_with_index
          .reduce(attributes) do |result, (change, index)|
            change.current_attributes(result, existing: existing.after(change))
          rescue VersionChange::Converter::Failure => failure
            raise failure.convert_names { previous_names(it, changes: changes.take(index)) }
          end
      end

      def declared_names(name)
        current_names(name).tap do |names|
          names.each { raise Correction.new(it) if previous_names(it).exclude?(name) }
        end
      end

      def member_name(name) = previous_names(name).first

      def member_attributes(attributes)
        changes
          .reverse_each
          .reduce(attributes) { |result, change| change.previous_attributes(result) }
      end

      private

      attr_reader :changes

      def current_names(name)
        changes.reduce([name]) { |names, change| names.flat_map { change.current_names(it) }.uniq }
      end

      def previous_names(name, changes: self.changes)
        changes
          .reverse_each
          .reduce([name]) { |names, change| names.flat_map { change.previous_names(it) }.uniq }
      end
    end
  end
end
