# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Naming
      extend ActiveSupport::Concern

      MissingDeclaration = Class.new(StandardError)

      NAMING = /\A(?<path>(?:\w+::)*(?<subject>\w+))Resource\z/
      private_constant :NAMING

      included do
        class_attribute :declared_model,
                        :declared_type,
                        instance_accessor: false,
                        instance_predicate: false
        private_class_method :declared_model, :declared_model=, :declared_type, :declared_type=
      end

      class_methods do
        def model(declaration = nil)
          return resolved_model unless declaration
          @resolved_model = nil
          self.declared_model = declaration
        end

        def schema = Schema.new(model)

        def type(declaration = nil)
          return declared_type || inferred_type unless declaration
          self.declared_type = declaration.to_s
        end

        private

        def resolved_model = @resolved_model ||= model_for(declared_model || name_parts[:path])

        def model_for(model)
          model.to_s.camelize.safe_constantize or raise MissingDeclaration, no_model(model)
        end

        def inferred_type = @inferred_type ||= name_parts[:subject].underscore.pluralize

        def name_parts
          name&.match(NAMING) or raise MissingDeclaration, nothing_to_infer_from
        end

        def no_model(model)
          "#{self}: no model is named #{model.to_s.camelize}, declare it with `model SomeModel`"
        end

        def nothing_to_infer_from
          "#{inspect} is not named after what it exposes: declare `model SomeModel` and `type :things`"
        end
      end
    end
  end
end
