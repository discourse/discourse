# frozen_string_literal: true

module JsonApiKit
  class BaseController
    module Serving
      extend ActiveSupport::Concern

      MissingDeclaration = Class.new(StandardError)

      included { class_attribute :declared_resource, instance_accessor: false }

      class_methods do
        def resource(declaration)
          self.declared_resource = ResourceLookup.resource(declaration, within: self)
        end
      end

      private

      def resource
        self.class.declared_resource or
          raise MissingDeclaration,
                "#{self.class}: declare the resource it serves with `resource :things`"
      end
    end
  end
end
