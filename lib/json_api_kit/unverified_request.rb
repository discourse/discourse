# frozen_string_literal: true

module JsonApiKit
  class UnverifiedRequest < Forbidden
    HEADER = "X-CSRF-Token"

    def initialize(detail = "A session request must send a valid #{HEADER}.")
      super
    end

    def source = { header: HEADER }
  end
end
