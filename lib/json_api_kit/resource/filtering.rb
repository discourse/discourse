# frozen_string_literal: true

module JsonApiKit
  class Resource
    # How a resource lets its listings be narrowed: the filters it offers a caller, each with the
    # type its value is read as and what that value does to a scope. It records them and hands them
    # to `Declarations::Filters`, which narrows a scope by the ones a request names.
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
        # Declares a way this resource's listings may be narrowed. A filter over a column of the
        # model needs only its name — `filter :title` — and a block where equality is not the
        # condition wanted.
        def filter(name, &condition)
          self.declared_filters = declared_filters + [Declarations::Filter.new(name, &condition)]
        end

        # Everything this resource says about narrowing its listings, as one collaborator. Built
        # each time rather than held, since a plugin declares filters long after a class body ran.
        def filters = Declarations::Filters.new(declared_filters)
      end
    end
  end
end
