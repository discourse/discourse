# frozen_string_literal: true

module JsonApiKit
  class Forbidden < Error
    def initialize(detail = "You are not allowed to make this request.")
      super
    end

    def status = "403"

    def title = "Forbidden"
  end
end
