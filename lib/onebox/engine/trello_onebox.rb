# frozen_string_literal: true

module Onebox
  module Engine
    class TrelloOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https:\/\/trello\.com\/[bc]\/\W*/)
      always_https

      def to_html
        link = "https://trello.com/#{match[:type]}/#{match[:key]}.html"

        height = match[:type] == 'b' ? 400 : 200

        <<-HTML
          <iframe src=\"#{link}\" width=\"100%\" height=\"#{height}\" frameborder=\"0\" style=\"border:0\"></iframe>
        HTML
      end

      private
      def match
        return @match if @match

        @match = @url.match(%{trello\.com/(?<type>[^/]+)/(?<key>[^/]+)/?\W*})

        @match
      end
    end
  end
end
