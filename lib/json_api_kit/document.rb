# frozen_string_literal: true

module JsonApiKit
  class Document
    def self.build(parameters, resource:, urls:, glossary:)
      declared_parameters = Request::Parameters.new(parameters.to_hash, glossary:).to_h
      contract_class
        .new(
          **declared_parameters.deep_dup,
          options: {
            resource:,
            raw_parameters: declared_parameters.with_indifferent_access,
          },
        )
        .then do |contract|
          if contract.invalid?
            next(Errors.new(*Request::Contract::Mapper.new(contract.errors, glossary:).to_a))
          end
          new(yield(contract.to_hash), urls:, glossary:).tap(&:to_h)
        end
    rescue Error => error
      Errors.new(error)
    end
    private_class_method :build

    def initialize(query, urls:, glossary:)
      @query = query
      @urls = urls
      @glossary = glossary
    end

    def to_h = @to_h ||= { data:, included:, links: }

    def status = "200"

    private

    attr_reader :query, :urls, :glossary

    def contents = @contents ||= Contents.new(primary_records, query.included)

    def links = { self: { href: urls.current.to_s, type: Pagination::Profile::MEDIA_TYPE } }

    def included = contents.related.map { ResourceObject.new(it, urls:, glossary:).to_h }
  end
end
