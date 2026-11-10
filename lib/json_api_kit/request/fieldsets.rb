# frozen_string_literal: true

module JsonApiKit
  class Request
    class Fieldsets
      def self.parse(raw) = new(raw.to_h.transform_values { Fieldset.parse(it) }.compact)

      def initialize(fieldsets)
        @fieldsets = fieldsets
      end

      def keep(type, attributes) = fieldsets.fetch(type, Fieldset::All).keep(attributes)

      private

      attr_reader :fieldsets
    end
  end
end
