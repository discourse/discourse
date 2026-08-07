# frozen_string_literal: true

module JsonApiKit
  class Resource
    # How large a page of this resource may be: what it reads when a request asks for no size, and
    # the most it will read when one does. A resource that declares nothing reads the kit's own
    # sizes (see Declarations::PageLimits).
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
        # Declares either bound, or both — `page default: 20, max: 50`.
        def page(default: nil, max: nil)
          self.declared_page_limits = { default:, max: }.compact
        end

        # What this resource says about the size of its pages, as one collaborator.
        def page_limits = Declarations::PageLimits.new(**declared_page_limits)
      end
    end
  end
end
