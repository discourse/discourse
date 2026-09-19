# frozen_string_literal: true

module JsonApiKit
  class Document
    class ErrorObject
      delegate :status, :title, :detail, :source, :meta, to: :error, private: true

      def initialize(error)
        @error = error
      end

      def to_h = { status:, title:, detail:, source:, links:, meta: }.compact_blank

      private

      attr_reader :error

      def links = error.type.try { { type: it } }
    end
  end
end
