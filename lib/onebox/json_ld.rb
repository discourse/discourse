# frozen_string_literal: true

module Onebox
  class JsonLd < Normalizer
    # Full schema.org hierarchy can be found here: https://schema.org/docs/full.html
    MOVIE_JSON_LD_TYPE = "Movie"

    def initialize(doc)
      @data = extract(doc)
    end

    private

    def extract(doc)
      return {} if Onebox::Helpers::blank?(doc)

      doc.css('script[type="application/ld+json"]').each do |element|
        parsed_json = parse_json(element.text)

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
