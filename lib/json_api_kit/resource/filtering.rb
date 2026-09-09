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
        def filter(name, &condition)
          self.declared_filters = declared_filters + [Declarations::Filter.new(name, &condition)]
        end

        def apply_filters(rows, filtering = {}) = filters.apply(rows, filtering)

        def filter_names = declared_filters.map(&:name)

        private

        def filters = Declarations::Filters.new(declared_filters)
      end
    end
  end
end
