# frozen_string_literal: true

module JsonApiKit
  class UnsupportedMediaType < Error
    def status = "415"

    def title = "Unsupported media type"
  end
end
