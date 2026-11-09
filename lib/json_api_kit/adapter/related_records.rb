# frozen_string_literal: true

module JsonApiKit
  class Adapter
    class RelatedRecords
      def initialize(resource, owners:)
        @resource = resource
        @owners = owners
      end

      def scope
        raise NotImplementedError, "#{self.class} must implement #scope."
      end

      def records_by_owner(params)
        records(params).then do |records|
          pair(records.map(&:record)).transform_values { records.fetch_all(it) }
        end
      end

      private

      attr_reader :resource, :owners

      def records(params) = resource.all(params, scoped_to: sideload_scope).records

      # Inclusion can require per-owner pagination instead of the related endpoint's pagination.
      def sideload_scope = scope

      # Maps underlying owners to arrays of the supplied underlying records.
      def pair(_records)
        raise NotImplementedError, "#{self.class} must implement #pair."
      end
    end
  end
end
