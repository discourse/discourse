# frozen_string_literal: true

module JsonApiKit
  class Resource
    # How a listing of this resource is asked for: the rows it can ever expose, and the queries
    # read from them. A resource hands back a query rather than records, so a caller can pass it on
    # — a sideload and a nested route read the same query, scoped to another listing's rows.
    module QueryInterface
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_scope, instance_accessor: false, instance_predicate: false
        private_class_method :declared_scope, :declared_scope=
      end

      class_methods do
        # Declares the rows this resource can ever expose, given who is asking: every listing it
        # reads narrows them, none widens them. Its model's rows when it declares none.
        def scope(&block)
          self.declared_scope = block
        end

        # The rows on offer to whoever is asking.
        def scope_for(guardian)
          return model.all unless declared_scope
          declared_scope.call(guardian)
        end

        # A listing of this resource, read lazily for whoever is asking, and kept to another
        # listing's rows when it is read as part of one.
        def all(params = {}, guardian:, scoped_to: nil)
          Query.new(self, params, guardian:, scoped_to:)
        end
      end
    end
  end
end
