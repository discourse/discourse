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
      json_ld = doc.search('script[type="application/ld+json"]')
      return {} if Onebox::Helpers::blank?(json_ld.text)
      
      json_ld_items = JSON[json_ld.text]

      return {} unless json_ld_items["@type"] == MOVIE_JSON_LD_TYPE
      Onebox::Movie.new(json_ld_items).to_h
    end
  end
end
