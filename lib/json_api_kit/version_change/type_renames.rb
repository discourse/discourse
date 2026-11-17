# frozen_string_literal: true

module JsonApiKit
  class VersionChange
    class TypeRenames < NameChanges
      def current(type) = current_names(Name::Type.new(value: type)).sole.value

      def previous(type) = previous_names(Name::Type.new(value: type)).sole.value
    end
  end
end
