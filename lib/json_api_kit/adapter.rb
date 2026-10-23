# frozen_string_literal: true

module JsonApiKit
  class Adapter
    class << self
      def anchor(...) = definition_class.anchor(...)

      def required_owner_fields(...) = definition_class.required_owner_fields(...)

      def schema(resource) = definition_for(resource).schema

      def order(resource, ordering) = definition_for(resource).order(ordering)

      def paged_from?(resource, cursor, ordering:)
        definition_for(resource).paged_from?(cursor, ordering:)
      end

      def anchored_by?(resource, anchor_name:, ordering:)
        definition_for(resource).anchored_by?(anchor_name:, ordering:)
      end

      def definition_for(resource)
        definition_class.new(Declarations::Resource.new(resource))
      end

      private

      def definition_class = const_get(:Definition)
    end

    delegate :schema,
             :order,
             :sort_key,
             :paged_from?,
             :anchored_by?,
             :leading_sort_name,
             :parse_cursor,
             :valid_cursor?,
             to: :definition

    def initialize(resource)
      @resource = resource
    end

    def collection?(value) = value.is_a?(Array)

    private

    attr_reader :resource

    def definition = @definition ||= self.class.definition_for(resource)
  end
end
