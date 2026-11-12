# frozen_string_literal: true

module JsonApiKit
  class MediaType
    JSON_API = "application/vnd.api+json"
    ALLOWED = %w[ext profile].freeze
    WEIGHT = "q"

    def self.parse(header) = header.to_s.split(",").filter_map { new(it) if it.present? }

    def initialize(declaration)
      @declaration = declaration.strip
    end

    def json_api? = Rack::MediaType.type(declaration) == JSON_API

    def modified? = (names - ALLOWED).any?

    def extended? = names.include?("ext")

    private

    attr_reader :declaration

    def names = @names ||= Rack::MediaType.params(declaration).keys - [WEIGHT]
  end
end
