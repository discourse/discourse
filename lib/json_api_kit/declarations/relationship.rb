# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      UnsupportedRule = Class.new(StandardError)

      attr_reader :name, :resource

      delegate :readable_by?, to: :readable

      def initialize(name, resource:, readable: Readable::ALWAYS)
        @name = name.to_s
        @resource = resource
        @readable = Readable.for(readable)
        verify_readable_block
      end

      def listing(params, guardian:, scoped_to:) = resource.all(params, guardian:, scoped_to:)

      def resolves?(path) = resource.resolves?(path)

      private

      attr_reader :readable

      def verify_readable_block
        return unless readable.per_record?
        raise UnsupportedRule,
              "#{name}: having both a guardian and a record for a relationship isn’t supported"
      end
    end
  end
end
