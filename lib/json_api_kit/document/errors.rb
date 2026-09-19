# frozen_string_literal: true

module JsonApiKit
  class Document
    class Errors
      def initialize(*errors)
        @errors = errors
      end

      def status = errors.first.status

      def to_h = { errors: errors.map { ErrorObject.new(it).to_h } }

      private

      attr_reader :errors
    end
  end
end
