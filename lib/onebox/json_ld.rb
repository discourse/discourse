# frozen_string_literal: true

module Onebox
  class JsonLd < Normalizer
    # Full schema.org hierarchy can be found here: https://schema.org/docs/full.html
    EVENT_JSON_LD_TYPE = "Event"
    MOVIE_JSON_LD_TYPE = "Movie"
    SUPPORTED_TYPES = [EVENT_JSON_LD_TYPE, MOVIE_JSON_LD_TYPE]

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
          when EVENT_JSON_LD_TYPE
            return event_data(parsed_json)
          when MOVIE_JSON_LD_TYPE
            return Onebox::Movie.new(parsed_json).to_h
          end
        end

      {}
    end

    def event_data(json)
      starts_at = json["startDate"]
      image = event_image(json["image"])

      {
        event_starts_at: starts_at,
        event_ends_at: json["endDate"],
        event_all_day: date_only?(starts_at).to_s,
        event_description: json["description"],
        **{
          event_image: image[:url],
          event_image_width: image[:width],
          event_image_height: image[:height],
        }.compact,
      }
    end

    # Schema.org allows a URL, an ImageObject, or a list of either
    def event_image(value)
      value = value.first if value.is_a?(Array)

      case value
      when String
        { url: value }
      when Hash
        {
          url: [value["url"], value["contentUrl"]].find { |url| url.is_a?(String) },
          width: dimension(value["width"]),
          height: dimension(value["height"]),
        }
      else
        {}
      end
    end

    # Kept as strings like the rest of the normalized data; QuantitativeValue wraps the number
    def dimension(value)
      value = value["value"] if value.is_a?(Hash)
      value.to_s if value.to_s.to_i.positive?
    end

    def date_only?(value)
      Date.iso8601(value.to_s).iso8601 == value.to_s
    rescue Date::Error
      false
    end

    def parse_json(json)
      JSON[json]
    rescue JSON::ParserError => e
      Discourse.warn_exception(e, message: "Error parsing JSON-LD: #{json}")
      {}
    end
  end
end
