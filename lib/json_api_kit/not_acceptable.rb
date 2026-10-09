# frozen_string_literal: true

module JsonApiKit
  class NotAcceptable < Error
    def status = "406"

    def title = "Not acceptable"
  end
end
