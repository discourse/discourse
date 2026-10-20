# frozen_string_literal: true

require_relative "matcher"

module JsonApiKitMatchers
  class Paginate < Matcher
    attr_reader :default, :max

    def initialize(default:, max:)
      @default = default
      @max = max
    end

    def satisfied?
      resource.page_size == default && resource.max_page_size == max
    end

    def description
      "paginate #{default} rows at a time, #{max} at most"
    end

    def failure_message
      "Expected #{resource} to #{description}, but it paginates #{resource.page_size} " \
        "at a time, #{resource.max_page_size} at most."
    end
  end
end
