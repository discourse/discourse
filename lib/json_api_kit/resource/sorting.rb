# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Sorting
      extend ActiveSupport::Concern

      UndeclaredDefault = Class.new(StandardError)

      included do
        class_attribute :declared_unique_by, instance_accessor: false, instance_predicate: false
        class_attribute :declared_sorts,
                        default: [].freeze,
                        instance_accessor: false,
                        instance_predicate: false
        class_attribute :declared_default_sort,
                        default: {}.freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_sorts,
                             :declared_sorts=,
                             :declared_default_sort,
                             :declared_default_sort=,
                             :declared_unique_by,
                             :declared_unique_by=
      end

      class_methods do
        include Ordering

        def sort(name, **options)
          self.declared_sorts = declared_sorts + [Declarations::Sort.for(name, **options)]
        end

        def default_sort(ordering)
          self.declared_default_sort = default_ordering(ordering)
        end

        def unique_by(*columns)
          self.declared_unique_by = columns
        end

        def sort_names = declared_sorts.map(&:name)

        def sorts
          Declarations::Sorts.new(declared_sorts, schema:, unique_by: declared_unique_by)
        end

        private

        def current_default_ordering = declared_default_sort
      end

      include Ordering

      delegate :names, to: :sorts, prefix: :sort

      def sorts = @sorts ||= self.class.sorts.with(edition.removed_sorts.for(type))

      private

      def current_default_ordering = self.class.default_ordering
    end
  end
end
