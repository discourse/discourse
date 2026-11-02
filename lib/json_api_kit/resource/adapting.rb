# frozen_string_literal: true

module JsonApiKit
  class Resource
    module Adapting
      extend ActiveSupport::Concern

      included do
        class_attribute :declared_adapter, default: Adapters::ActiveRecord, instance_accessor: false
        private_class_method :declared_adapter, :declared_adapter=
      end

      class_methods do
        def adapter(declaration = nil)
          return declared_adapter unless declaration
          self.declared_adapter =
            case declaration
            when Class
              declaration
            else
              Adapters.const_get(declaration.to_s.camelize, false)
            end
        end
      end

      def adapter = @adapter ||= self.class.adapter.new(self)
    end
  end
end
