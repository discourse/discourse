# frozen_string_literal: true

module JsonApiKit
  class Document
    class << self
      private

      def build(raw, resource:, urls:, glossary:)
        parameters = Request::Parameters.new(raw.to_hash.deep_stringify_keys, glossary:, resource:)
        contract = contract_class.for(parameters.to_h, resource:, glossary:)
        return Errors.new(*contract.refusals) if contract.invalid?
        assemble(new(yield(contract.to_hash), urls:, glossary:, fieldsets: parameters.fieldsets))
      rescue Error => error
        Errors.new(error)
      end

      def assemble(document) = document.tap(&:to_h)
    end

    def initialize(query, urls:, glossary:, fieldsets:)
      @query = query
      @urls = urls
      @glossary = glossary
      @fieldsets = fieldsets
    end

    def to_h = @to_h ||= { data:, included:, links: }

    def status = "200"

    private

    attr_reader :query, :urls, :glossary, :fieldsets

    def contents = @contents ||= Contents.new(primary_records, query.included)

    def links = { self: { href: urls.current.to_s, type: Pagination::Profile::MEDIA_TYPE } }

    def included
      contents.related.map { ResourceObject.new(it, urls:, glossary:, fieldsets:).to_h }
    end
  end
end
