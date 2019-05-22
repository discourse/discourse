# frozen_string_literal: true

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

              <div class="video" style="--aspect-ratio: #{data[:width]}/#{data[:height]}">
                <video controls loop muted poster="#{data[:posterUrl]}">
                  <source id="webmSource" src="#{data[:webmUrl]}" type="video/webm">
                  <source id="mp4Source" src="#{data[:mp4Url]}" type="video/mp4">
                  <img title="Sorry, your browser doesn't support HTML5 video." src="#{data[:posterUrl]}">
                </video>
              </div>
              <p>
                <span class="label1">#{data[:keywords]}</span>
              </p>

            </article>
          </aside>
        HTML
      end

      def placeholder_html
        <<-HTML
          <a href="#{data[:url]}">
            <img src="#{data[:posterUrl]}" width="#{data[:width]}" height="#{data[:height]}"><br/>
            #{data[:name]}
          </a>
        HTML
      end

      private

      def match
        @match ||= @url.match(/^https?:\/\/gfycat\.com\/(gifs\/detail\/)?(?<name>.+)/)
      end

      def nokogiri_page
        @nokogiri_page ||= begin
          response = Onebox::Helpers.fetch_response(url, 10) rescue nil
          Nokogiri::HTML(response)
        end
      end

      def get_og_data
        og_data = {}

        if json_string = nokogiri_page.at_css('script[type="application/ld+json"]')&.text
          og_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(json_string))
        end

        og_data
      end

      def data
        og_data = get_og_data

        response = {
          name: match[:name],
          title: og_data[:headline] || 'No Title',
          author: og_data[:author],
          url: @url
        }

        keywords = og_data[:keywords]&.split(',')
        if keywords
          response[:keywords] = keywords.map { |t| "<a href='https://gfycat.com/gifs/search/#{t}'>##{t}</a>" }.join(' ')
        end

        if og_data[:video]
          content_url = ::Onebox::Helpers.normalize_url_for_output(og_data[:video][:contentUrl])
          video_url = Pathname.new(content_url)
          response[:webmUrl] = video_url.sub_ext(".webm").to_s
          response[:mp4Url] = video_url.sub_ext(".mp4").to_s

          thumbnail_url = ::Onebox::Helpers.normalize_url_for_output(og_data[:video][:thumbnailUrl])
          response[:posterUrl] = thumbnail_url

          response[:width] = og_data[:video][:width]
          response[:height] = og_data[:video][:height]
        end

        response
      end
    end
  end
end
