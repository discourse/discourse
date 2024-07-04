# frozen_string_literal: true

module Onebox
  module Engine
    module JSON
      private

      def raw(http_headers = {})
        @raw ||= ::MultiJson.load(URI.parse(url).open(options.merge(http_headers)))
      end

      def options
        { read_timeout: timeout }
      end
    end
  end
end
