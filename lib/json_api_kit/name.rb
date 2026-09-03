# frozen_string_literal: true

module JsonApiKit
  module Name
    def convert = with(value: yield(value))

    def to_s = value
  end
end
