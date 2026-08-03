# frozen_string_literal: true

module JsonApiKit
  class NotFound < Error
    def initialize(detail = "No record has this ID.")
      super
    end

    def status = "404"

    def title = "No such record"
  end
end
