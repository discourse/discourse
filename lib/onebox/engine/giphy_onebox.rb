module Onebox
  module Engine
    class GiphyOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(giphy\.com\/gifs|gph\.is)\//)
      always_https

      def to_html
        oembed = get_oembed

        <<-HTML
          <a href="#{oembed.url}" target="_blank" class="onebox">
            <img src="#{oembed.url}" width="#{oembed.width}" height="#{oembed.height}" #{oembed.title_attr}>
          </a>
        HTML
      end

    end
  end
end
