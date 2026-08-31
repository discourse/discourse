# frozen_string_literal: true

module JsonApiKit
  class Resource
    module QueryInterface
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_scope, instance_accessor: false, instance_predicate: false
        private_class_method :declared_scope, :declared_scope=
      end

      class_methods do
        def scope(&block)
          self.declared_scope = block
        end

        def scope_for(guardian)
          return model.all unless declared_scope
          declared_scope.call(guardian)
        end

        def all(params = {}, guardian:, scoped_to: nil)
          Query::Collection.new(self, Request::Collection.new(params, guardian:), scoped_to:)
        end

        def find(id, params = {}, guardian:)
          Query::Individual.new(self, Request::Individual.new(params.merge(id:), guardian:))
        end
      end
    end
  end
end
