# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      attr_reader :name, :resource

      def initialize(name, resource:)
        @name = name.to_s
        @resource = resource
      end

      def listing(params, guardian:, scoped_to:) = resource.all(params, guardian:, scoped_to:)

      def resolves?(path) = resource.resolves?(path)
    end
  end
end
