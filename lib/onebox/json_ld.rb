# frozen_string_literal: true

module Onebox
  class JsonLd < Normalizer
    # Full schema.org hierarchy can be found here: https://schema.org/docs/full.html
    MOVIE_JSON_LD_TYPE = "Movie"
    SUPPORTED_TYPES = [MOVIE_JSON_LD_TYPE].freeze

    def initialize(doc)
      @data = extract(doc)
    end

    private

    def extract(doc)
      return {} if doc.blank?

      doc
        .css('script[type="application/ld+json"]')
        .each do |element|
          parsed_json = parse_json(element.text)

          if parsed_json.kind_of?(Array)
            parsed_json = parsed_json.detect { |x| SUPPORTED_TYPES.include?(x["@type"]) }
            return {} if !parsed_json
          end

          case parsed_json["@type"]
          when MOVIE_JSON_LD_TYPE
            return Onebox::Movie.new(parsed_json).to_h
          end
        end

      {}
    end

    def parse_json(json)
      begin
        JSON[json]
      rescue JSON::ParserError => e
        Discourse.warn_exception(e, message: "Error parsing JSON-LD: #{json}")
        {}
      end
    end
  end
end
