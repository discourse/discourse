# frozen_string_literal: true

module JsonApiKit
  class Document
    def self.build(parameters, resource:, urls:)
      contract_class
        .new(
          **parameters,
          options: {
            resource:,
            raw_parameters: parameters.with_indifferent_access,
          },
        )
        .then do |contract|
          next Errors.new(*Request::Contract::Mapper.new(contract.errors).to_a) if contract.invalid?
          new(yield(contract.to_hash), urls:).tap(&:to_h)
        end
    rescue Error => error
      Errors.new(error)
    end
    private_class_method :build

    def initialize(query, urls:)
      @query = query
      @urls = urls
    end

    def to_h = @to_h ||= { data:, included:, links: }

    def status = "200"

    private

    attr_reader :query, :urls

    def contents = @contents ||= Contents.new(primary_records, query.included)

    def links = { self: urls.current.to_s }

    def included = contents.related.map { ResourceObject.new(it, urls:).to_h }
  end
end
