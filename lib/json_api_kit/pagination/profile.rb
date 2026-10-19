# frozen_string_literal: true

module JsonApiKit
  module Pagination
    module Profile
      URL = "https://jsonapi.org/profiles/ethanresnick/cursor-pagination"
      MAX_SIZE = "#{URL}/max-size-exceeded"
      RANGE_UNSUPPORTED = "#{URL}/range-pagination-not-supported"
      MEDIA_TYPE = %(#{MediaType::JSON_API};profile="#{URL}")
    end
  end
end
