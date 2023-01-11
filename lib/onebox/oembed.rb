# frozen_string_literal: true

module Onebox
  class Oembed < OpenGraph
    def initialize(response)
      @data = Onebox::Helpers.symbolize_keys(::MultiJson.load(response))

      # never use oembed from WordPress 4.4 (it's broken)
      @data.delete(:html) if @data[:html] && @data[:html]["wp-embedded-content"]
    end

    def html
      get(:html, nil, false)
    end
  end
end
