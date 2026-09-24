# frozen_string_literal: true

module JsonApiKit
  class Document
    class << self
      private

      def build(raw, resource:, client:)
        input = input_class.new(raw, resource:, edition: client.edition)
        return Errors.new(*input.refusals) if input.invalid?
        assemble(new(yield(input.to_h), client:, fieldsets: input.fieldsets))
      rescue Error => error
        Errors.new(error)
      end

      def assemble(document) = document.tap(&:to_h)
    end

    delegate :urls, to: :client, private: true

    def initialize(query, client:, fieldsets:)
      @query = query
      @client = client
      @fieldsets = fieldsets
    end

    def to_h = @to_h ||= { data:, included:, links: }

    def status = "200"

    private

    attr_reader :query, :client, :fieldsets

    def contents = @contents ||= Contents.new(primary_records, query.included)

    def links = { self: { href: urls.current.to_s, type: Pagination::Profile::MEDIA_TYPE } }

    def included
      contents.related.map { ResourceObject.new(it, client:, fieldsets:).to_h }
    end
  end
end
