# frozen_string_literal: true

module JsonApiKit
  class InternalServerError < Error
    def initialize(detail = "The server could not answer this request.")
      super
    end

    def status = "500"

    def title = "Internal server error"
  end
end
