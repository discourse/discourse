# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Filtering
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_filters,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_filters, :declared_filters=
      end

      class_methods do
        def filter(name, **options, &condition)
          # A second declaration would silently replace the first, inherited ones included.
          if filter_names.include?(name.to_s)
            raise ArgumentError, "#{self}: the filter #{name} is already declared"
          end
          self.declared_filters =
            declared_filters + [Declarations::Filter.new(name, **options, &condition)]
        end

        def filter_names = declared_filters.map(&:name)

        # The values that filters with a default apply when a request leaves them out.
        def filter_defaults = declared_filters.select(&:default?).to_h { [it.name, it.default] }

        def filters = Declarations::Filters.new(declared_filters)
      end

      delegate :names, to: :filters, prefix: :filter

      def apply_filters(rows, filtering = {})
        filtering = self.class.filter_defaults.merge(filtering).freeze
        context = Declarations::Filter::Context.new(guardian:, edition:, filtering:)
        filters.apply(rows, filtering, context)
      end

      def filters = @filters ||= self.class.filters.with(edition.removed_filters.for(type))
    end
  end
end
