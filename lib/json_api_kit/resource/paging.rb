# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Paging
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_page_limits,
                        default: {}.freeze,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_page_limits, :declared_page_limits=
      end

      class_methods do
        def page(default: nil, max: nil)
          self.declared_page_limits = declared_page_limits.merge({ default:, max: }.compact)
          page_limits
        end

        def page_limits = Page::Limits.new(**declared_page_limits)

        def page_size = page_limits.size

        def max_page_size = page_limits.max

        def paged_from?(cursor, ordering: {}) = order(ordering).compatible_with?(cursor:)
      end
    end
  end
end
