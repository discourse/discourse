# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Resource
      delegate :sorts, :unique_key, :anchor_declarations, to: :resource

      def initialize(resource)
        @resource = resource
      end

      def model = resource.model

      def type = resource.type

      private

      attr_reader :resource
    end
  end
end
