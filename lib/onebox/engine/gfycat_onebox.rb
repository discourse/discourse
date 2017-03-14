module Onebox
  module Engine
    class GfycatOnebox
      include Engine
      include JSON

      matches_regexp(/^https?:\/\/gfycat\.com\//)
      always_https

      def self.priority
        # This engine should have priority over WhitelistedGenericOnebox.
        1
      end

      def url
        "https://gfycat.com/cajax/get/#{match[:name]}"
      end

      def to_html
        <<-HTML
          <div>
            <video controls loop autoplay muted poster="#{data[:posterUrl]}" width="#{data[:width]}" height="#{data[:height]}">
              <source id="webmSource" src="#{data[:webmUrl]}" type="video/webm">
              <source id="mp4Source" src="#{data[:mp4Url]}" type="video/mp4">
              <img title="Sorry, your browser doesn't support HTML5 video." src="#{data[:posterUrl]}">
            </video><br/>
            <a href="#{data[:url]}">#{data[:name]}</a>
          </div>
        HTML
      end

      def placeholder_html
        <<-HTML
          <a href="#{data[:url]}">
            <img src="#{data[:posterUrl]}" width="#{data[:width]}" height="#{data[:height]}"><br/>
            #{data[:gfyName]}
          </a>
        HTML
      end

      private

        def match
          @match ||= @url.match(/^https?:\/\/gfycat\.com\/(?<name>.+)/)
        end

        def data
          {
            name: raw['gfyItem']['gfyName'],
            url: @url,
            posterUrl: raw['gfyItem']['posterUrl'],
            webmUrl: raw['gfyItem']['webmUrl'],
            mp4Url: raw['gfyItem']['mp4Url'],
            width: raw['gfyItem']['width'],
            height: raw['gfyItem']['height']
          }
        end

    end
  end
end
