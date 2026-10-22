# frozen_string_literal: true

module JsonApiKit
  class Resource
    # Narrowing that depends on the request and applies to every request. The resource's `scope`
    # stays the boundary of what the guardian may see; the input scope narrows within it.
    module InputScoping
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_input_scope,
                        default: nil,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_input_scope, :declared_input_scope=
      end

      class_methods do
        # An input the input scope reads. It never filters on its own, and its default is
        # required, since an input the request leaves out must still mean something.
        def scope_filter(name, default:) = filter(name, default:) { |rows, _value| rows }

        # Declares the input scope when given a block, and returns it otherwise.
        def input_scope(&block)
          return declared_input_scope unless block
          self.declared_input_scope = Declarations::InputScope.new(block)
        end

        def verify_input_scope! = declared_input_scope&.verify!(self)
      end

      def apply_input_scope(rows, filtering = {})
        input_scope = self.class.input_scope
        return rows if input_scope.nil?
        input_scope.apply(rows, guardian:, values: self.class.filter_defaults.merge(filtering))
      end
    end
  end
end
