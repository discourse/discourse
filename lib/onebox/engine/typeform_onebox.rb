# frozen_string_literal: true

module Onebox
  module Engine
    class TypeformOnebox
      include Engine

      matches_regexp(/^https?:\/\/[a-z0-9\-_]+\.typeform\.com\/to\/[a-zA-Z0-9]+/)
      requires_iframe_origins "https://*.typeform.com"
      always_https

      def to_html
        typeform_src = build_typeform_src

        <<~HTML
          <iframe
            src="#{typeform_src}"
            width="100%"
            height="600px"
            scrolling="no"
            frameborder="0"
          ></iframe>
        HTML
      end

      def placeholder_html
        ::Onebox::Helpers.generic_placeholder_html
      end

      private

      def build_typeform_src
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(@url)
        query_params = CGI::parse(URI::parse(escaped_src).query || '')

        return escaped_src if query_params.has_key?('typeform-embed')

        if query_params.empty?
          escaped_src += '?' unless escaped_src.end_with?('?')
        else
          escaped_src += '&'
        end

        escaped_src += 'typeform-embed=embed-widget'
      end
    end
  end
end
