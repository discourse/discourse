# frozen_string_literal: true

module Onebox
  class Oembed < OpenGraph
    def initialize(response)
      @data = ::MultiJson.load(response, symbolize_keys: true)

      # never use oembed from WordPress 4.4 (it's broken)
      @data.delete(:html) if @data[:html] && @data[:html]["wp-embedded-content"]
    end

    def html
      get(:html, nil, false)
    end
  end
end
