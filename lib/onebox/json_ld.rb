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
      extracted_json = extract_json_from(doc)
      parsed_json = parse_json(extracted_json)

      return {} unless parsed_json["@type"] == MOVIE_JSON_LD_TYPE

      Onebox::Movie.new(parsed_json).to_h
    end

    def extract_json_from(doc)
      return {} if Onebox::Helpers::blank?(doc)
      json_ld = doc.search('script[type="application/ld+json"]').text
      return {} if Onebox::Helpers::blank?(json_ld)
      json_ld
    end

    def parse_json(json)
      begin
        JSON[json]
      rescue JSON::ParserError => e
        Discourse.warn_exception(e, message: "Error parsing JSON-LD json: #{json}")
        {}
      end
    end
  end
end
