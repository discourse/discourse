# frozen_string_literal: true

module Onebox
  class Movie
    def initialize(json_ld_data)
      @json_ld_data = json_ld_data
    end

    def name
      @json_ld_data["name"]
    end

    def image
      @json_ld_data["image"]
    end

    def description
      @json_ld_data["description"]
    end

    def rating
      @json_ld_data.dig("aggregateRating", "ratingValue")
    end

    def genres
      @json_ld_data["genre"]
    end

    def duration
      return nil unless @json_ld_data["duration"]

      Time.parse(@json_ld_data["duration"]).strftime "%H:%M"
    end

    def to_h
      {
        name: name,
        image: image,
        description: description,
        rating: rating,
        genres: genres,
        duration: duration,
      }
    end
  end
end
