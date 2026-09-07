# frozen_string_literal: true

module JsonApiKit
  class Error < StandardError
    def detail = message

    def title = "Bad request"

    def source = {}

    def type = nil

    def meta = {}
  end
end
