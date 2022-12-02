# frozen_string_literal: true

module Onebox
  module Engine
    class TypeformOnebox
      include Engine

      matches_regexp(/^https?:\/\/embed\.smartcontracts\.org\/?.*/)
      requires_iframe_origins "https://embed.smartcontracts.org"
      always_https

      def to_html
        get_oembed.html
      end

      def placeholder_html
        ::Onebox::Helpers.generic_placeholder_html
      end

      protected

      def get_oembed_url
        "https://embed.smartcontracts.org/api/onebox?url=#{url}"
      end
    end
  end
end
