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

    # Returns a Query within the resource scope, narrowed by scoped_to and request filters.
    def all(request, scoped_to: nil)
      Query::Result.new(resource, request, records: records_for(request, scoped_to:))
    end

    def find(request)
      Query::Result.new(resource, request, records: [record_for(request.id)])
    end

    # Returns an underlying record within the resource scope, or raises NotFound.
    def record_for(_id)
      raise NotImplementedError, "#{self.class} must implement #record_for."
    end

    # Returns underlying records within the resource scope, narrowed by scoped_to and filters.
    def records_for(_request, scoped_to: nil)
      raise NotImplementedError, "#{self.class} must implement #records_for."
    end

    # Returns a native scope that the Kit can pass back to this adapter.
    def scope_for(_guardian)
      raise NotImplementedError, "#{self.class} must implement #scope_for."
    end

    # Applies a filter declared without a custom block.
    def filter(_scope, _name, _value)
      raise NotImplementedError, "#{self.class} must implement #filter."
    end

    # Returns an object with two operations:
    # - scope: a native scope accepted by all(scoped_to:).
    # - records_by_owner(params): a hash from underlying owners to JsonApiKit::Records.
    # Adapter::RelatedRecords supplies the loading and wrapping through scope and pair hooks.
    def related_records(_relationship, owners:, owner_resource:)
      raise NotImplementedError, "#{self.class} must implement #related_records."
    end

    def collection?(value) = value.is_a?(Array)

    private

    attr_reader :resource

    def definition = @definition ||= self.class.definition_for(resource)
  end
end
