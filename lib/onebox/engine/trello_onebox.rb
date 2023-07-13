# frozen_string_literal: true

module Onebox
  module Engine
    class TrelloOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https://trello\.com/[bc]/\W*})
      requires_iframe_origins "https://trello.com"
      always_https

      def to_html
        src = "https://trello.com/#{match[:type]}/#{match[:key]}.html"
        height = match[:type] == "b" ? 400 : 200

        <<-HTML
          <iframe src="#{src}" width="100%" height="#{height}" frameborder="0" style="border:0"></iframe>
        HTML
      end

      def placeholder_html
        ::Onebox::Helpers.generic_placeholder_html
      end

      private

      def match
        return @match if defined?(@match)
        @match = @url.match(%{trello\.com/(?<type>[^/]+)/(?<key>[^/]+)/?\W*})
      end
    end
  end
end
