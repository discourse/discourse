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

        def all(params = {}, guardian:, scoped_to: nil, edition: Edition.current)
          new(guardian:, edition:).all(params, scoped_to:)
        end

        def find(id, params = {}, guardian:, edition: Edition.current)
          new(guardian:, edition:).find(id, params)
        end
      end

      delegate :scope_for, to: :class
      delegate :default_sorts, to: :edition, private: true

      def current_values(id) = CurrentValues.new(self, id:)

      def all(params = {}, scoped_to: nil)
        Query::Collection.new(
          self,
          Request::Collection.new(
            Request::Input.with_defaults(params, resource: self, default_sorts:),
            guardian:,
            edition:,
          ),
          scoped_to:,
        )
      end

      def find(id, params = {})
        Query::Individual.new(
          self,
          Request::Individual.new(
            Request::Input.with_defaults(params, resource: self, default_sorts:).merge(id:),
            guardian:,
            edition:,
          ),
        )
      end

      def related_scope(name, owner_id:)
        schema.association(name.to_sym, [record_for(owner_id)]).related_scope
      end

      def record_for(id)
        scope_for(guardian).find_by(schema.primary_key => id) or raise NotFound
      end
    end
  end
end
