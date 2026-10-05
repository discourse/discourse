# frozen_string_literal: true

module JsonApiKit
  class Request
    class Input
      def self.with_defaults(parameters, resource:, default_sorts:)
        parameters.to_h.stringify_keys.then do |params|
          return params unless params["sort"].nil?
          params.merge("sort" => default_sorts.for(resource))
        end
      end

      def initialize(raw, resource:, edition:)
        @resource = resource
        @edition = edition
        @parameters = Parameters.new(raw.to_hash.deep_stringify_keys, resource:, glossary:)
      end

      delegate :invalid?, :refusals, to: :contract
      delegate :fieldsets, to: :parameters

      def to_h = contract.to_hash

      private

      attr_reader :resource, :edition, :parameters

      delegate :glossary, :default_sorts, to: :edition, private: true

      def contract = @contract ||= contract_class.for(contract_parameters, resource:, glossary:)

      def contract_parameters = parameters.to_h
    end
  end
end
