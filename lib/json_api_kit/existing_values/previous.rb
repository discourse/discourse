# frozen_string_literal: true

module JsonApiKit
  class ExistingValues
    class Previous
      def initialize(change, current:)
        @change = change
        @current = current
        @values = {}
      end

      def fetch(name)
        return current.fetch(name) unless change.affects?(name)
        values.merge!(previous_values(name)) unless values.key?(name)
        values.fetch(name).deep_dup
      end

      private

      attr_reader :change, :current, :values

      def previous_values(name)
        change.previous_attributes(current_attributes_for(name))
      rescue VersionChange::Converter::Failure => error
        raise ConversionFailure, error.message
      end

      def current_attributes_for(name)
        change.current_names(name).to_h { [it, current.fetch(it)] }
      end
    end
  end
end
