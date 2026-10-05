# frozen_string_literal: true

module JsonApiKit
  class Request
    class Body
      class Unreadable < BadRequest
        def title = "Invalid request body"

        def detail = "The request body must contain valid JSON."
      end

      def self.parse(json, resource:)
        new(JSON.parse(json), resource:)
      rescue JSON::ParserError
        raise Unreadable
      end

      def initialize(document, resource:)
        @document = document
        @resource = resource
      end

      delegate :invalid?, to: :contract

      def to_h = document

      def refusals = contract.errors.map { Error.new(it, document:) }

      private

      attr_reader :document, :resource

      delegate :edition, :type, to: :resource
      delegate :glossary, to: :edition

      def contract = @contract ||= Contract.new(document, type: glossary.member_type(type))
    end
  end
end
