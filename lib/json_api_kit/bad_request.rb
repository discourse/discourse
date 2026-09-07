# frozen_string_literal: true

module JsonApiKit
  class BadRequest < Error
    def status = "400"
  end
end
