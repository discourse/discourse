module Onebox
  module Engine
    class WistiaOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/https?:\/\/(.+)?(wistia.com|wi.st)\/(medias|embed)\/.*/)
      always_https

      def placeholder_html
        tw = get_twitter
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(tw[:image])
        "<img src='#{escaped_src}' height='#{tw[:player_height]}' #{Helpers.title_attr(tw)}>"
      end

      def to_html
        tw = get_twitter
        src = tw[:url].gsub("?twitter=true", "")
        escaped_src = ::Onebox::Helpers.normalize_url_for_output(src)

        <<-HTML
          <iframe src="#{escaped_src}"
                  width="640"
                  height="360"
                  scrolling="no"
                  frameborder="0"
                  allowtransparency="true"
                  allowfullscreen>
          </iframe>
        HTML
      end
    end
  end
end
