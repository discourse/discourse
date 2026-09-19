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
        delegate :default_sorts, to: "JsonApiKit::Edition.current", prefix: :current, private: true

        def scope(&block)
          self.declared_scope = block
        end

        def scope_for(guardian)
          return model.all unless declared_scope
          declared_scope.call(guardian)
        end

        def all(params = {}, guardian:, scoped_to: nil, default_sorts: current_default_sorts)
          Query::Collection.new(
            self,
            Request::Collection.new(
              Request::Input.with_defaults(params, resource: self, default_sorts:),
              guardian:,
              default_sorts:,
            ),
            scoped_to:,
          )
        end

        def find(id, params = {}, guardian:, default_sorts: current_default_sorts)
          Query::Individual.new(
            self,
            Request::Individual.new(
              Request::Input.with_defaults(params, resource: self, default_sorts:).merge(id:),
              guardian:,
              default_sorts:,
            ),
          )
        end
      end
    end
  end
end
