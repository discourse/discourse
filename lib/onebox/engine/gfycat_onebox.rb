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
          <aside class="onebox gfycat">
            <header class="source">
              <img src="https://gfycat.com/static/favicons/favicon-96x96.png" class="site-icon" width="64" height="64">
              <a href="#{data[:url]}" target="_blank" rel="nofollow noopener">Gfycat.com</a>
            </header>
            <article class="onebox-body">
              <h4>
                #{data[:title]} by
                <a href="https://gfycat.com/@#{data[:author]}" target="_blank" rel="nofollow noopener">
                  <span>#{data[:author]}</span>
                </a>
              </h4>

              <div class="video">
                <video controls loop #{data[:autoplay]} muted poster="#{data[:posterUrl]}" style="--aspect-ratio: #{data[:width]}/#{data[:height]}">
                  <source id="webmSource" src="#{data[:webmUrl]}" type="video/webm">
                  <source id="mp4Source" src="#{data[:mp4Url]}" type="video/mp4">
                  <img title="Sorry, your browser doesn't support HTML5 video." src="#{data[:posterUrl]}">
                </video>
              </div>
              <p>
                <span class="label1">#{data[:tags]}</span>
              </p>

            </article>
          </aside>
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
        @match ||= @url.match(/^https?:\/\/gfycat\.com\/(gifs\/detail\/)?(?<name>.+)/)
      end

      def data

        total_tags = [raw['gfyItem']['tags'], raw['gfyItem']['userTags']].flatten.compact
        tag_links = total_tags.map { |t| "<a href='https://gfycat.com/gifs/search/#{t}'>##{t}</a>" }.join(' ') if total_tags
        autoplay = raw['gfyItem']['webmSize'].to_i < 10485760 ? 'autoplay' : ''

        {
          name: raw['gfyItem']['gfyName'],
          title: raw['gfyItem']['title'] || 'No Title',
          author: raw['gfyItem']['userName'],
          tags: tag_links,
          url: @url,
          posterUrl: raw['gfyItem']['posterUrl'],
          webmUrl: raw['gfyItem']['webmUrl'],
          mp4Url: raw['gfyItem']['mp4Url'],
          width: raw['gfyItem']['width'],
          height: raw['gfyItem']['height'],
          autoplay: autoplay
        }
      end

    end
  end
end
