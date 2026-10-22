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

        def verify_input_scope!
          declared_input_scope&.verify!(self, names: filter_names, defaults: filter_defaults.keys)
        end
      end

      # The input scope a version change retained for this edition, or the current one.
      def input_scope
        return @input_scope if defined?(@input_scope)
        @input_scope =
          edition.input_scopes.for(type, collection: collection_name).to_a.last&.input_scope ||
            self.class.input_scope
      end

      def verify_input_scope!
        input_scope&.verify!(
          self.class,
          names: filter_bindings.keys,
          defaults: filter_bindings.select { |_name, filter| filter.default? }.keys,
        )
      end

      def apply_input_scope(rows, filtering = {})
        return rows if input_scope.nil?
        values = filter_values(filtering)
        inputs =
          filter_bindings.each_with_object({}) do |(input, filter), bound|
            bound[input] = values[filter.name] if values.key?(filter.name)
          end
        input_scope.apply(rows, guardian:, values: inputs)
      end
    end
  end
end
