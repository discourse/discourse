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

        def filter_declarations = declared_filters

        # The values that filters with a default apply when a request leaves them out.
        def filter_defaults = declared_filters.select(&:default?).to_h { [it.name, it.default] }

        def filters = Declarations::Filters.new(declared_filters)
      end

      delegate :names, to: :filters, prefix: :filter

      def apply_filters(rows, filtering = {})
        filtering = filter_values(filtering)
        context = Declarations::Filter::Context.new(guardian:, edition:, filtering:)
        filters.apply(rows, filtering, context)
      end

      # Each filter name a request at this edition may use, bound to the declaration it reaches:
      # the oldest removal after the pin when one retained the name, as the glossary binds it,
      # and the current declaration otherwise.
      def filter_bindings
        @filter_bindings ||=
          edition
            .removed_filters
            .for(type, collection: collection_name)
            .each_with_object(
              self.class.filter_declarations.index_by(&:name),
            ) { |removed, bindings| bindings[removed.original_name] = removed }
            .freeze
      end

      # The request's values with the default of every filter it can reach. A current filter that a
      # removal shadows lends no default to the requests that removal serves.
      def filter_values(filtering)
        filter_bindings
          .each_value
          .select(&:default?)
          .to_h { [it.name, it.default] }
          .merge(filtering)
          .freeze
      end

      def filters
        @filters ||=
          self.class.filters.with(edition.removed_filters.for(type, collection: collection_name))
      end
    end
  end
end
