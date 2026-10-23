# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Resource
      delegate :model, :type, :sorts, :unique_key, :anchor_declarations, to: :resource

      def initialize(resource)
        @resource = resource
      end

      private

      attr_reader :resource
    end
  end
end
