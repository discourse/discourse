# frozen_string_literal: true

module JsonApiKit
  module Declarations
    class Relationship
      UnsupportedRule = Class.new(StandardError)

      attr_reader :name, :resource

      delegate :readable_by?, to: :readable

      def initialize(name, resource:, readable: Readable::ALWAYS, writable: false)
        @name = name.to_s
        @resource = resource
        @readable = Readable.for(readable)
        @writable = writable
        verify_writable
        verify_readable_block
      end

      def writable? = @writable

      def writable_with?(http_method) = writable? && write_methods.include?(http_method)

      def contract_for(location:, glossary:)
        input_contract.new(location:, type: glossary.member_type(resource.type))
      end

      def resolves?(path) = resource.resolves?(path)

      private

      attr_reader :readable

      def write_methods
        raise NotImplementedError, "#{self.class} must implement #write_methods."
      end

      def input_contract
        raise NotImplementedError, "#{self.class} must implement #input_contract."
      end

      def verify_writable
        return if [true, false].include?(@writable)
        raise ArgumentError, "#{name}: writable must be true or false."
      end

      def verify_readable_block
        return unless readable.per_record?
        raise UnsupportedRule,
              "#{name}: relationship readability blocks cannot accept a record argument."
      end
    end
  end
end
