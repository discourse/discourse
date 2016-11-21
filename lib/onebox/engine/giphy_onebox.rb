module Onebox
  module Engine
    class GiphyOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(giphy\.com\/gifs|gph\.is)\//)

      def to_html
        oembed = get_oembed

        <<-HTML
          <a href="#{oembed[:url]}" target="_blank">
            <img src="#{oembed[:image]}" width="#{oembed[:width]}" height="#{oembed[:height]}">
          </a>
        HTML
      end

    end
  end
end
