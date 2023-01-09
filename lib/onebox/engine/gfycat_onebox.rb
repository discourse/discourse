# frozen_string_literal: true

module Onebox
  module Engine
    class GfycatOnebox
      include Engine
      include JSON

      matches_regexp(%r{^https?://gfycat\.com/})
      always_https

      # This engine should have priority over AllowlistedGenericOnebox.
      def self.priority
        1
      end

      def to_html
        <<-HTML
          <aside class="onebox gfycat">
            <header class="source">
              <img src="https://gfycat.com/static/favicons/favicon-96x96.png" class="site-icon" width="64" height="64">
              <a href="#{data[:url]}" target="_blank" rel="nofollow ugc noopener">Gfycat.com</a>
            </header>

            <article class="onebox-body">
              <h4>
                #{data[:title]} by
                <a href="https://gfycat.com/@#{data[:author]}" target="_blank" rel="nofollow ugc noopener">
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

            <div style="clear: both"></div>
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
        @match ||= @url.match(%r{^https?://gfycat\.com/(gifs/detail/)?(?<name>.+)})
      end

      def og_data
        return @og_data if defined?(@og_data)

        response =
          begin
            Onebox::Helpers.fetch_response(url, redirect_limit: 10)
          rescue StandardError
            nil
          end
        page = Nokogiri.HTML(response)
        script = page.at_css('script[type="application/ld+json"]')

        if json_string = script&.text
          @og_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(json_string))
        else
          @og_data = {}
        end
      end

      def data
        return @data if defined?(@data)

        @data = {
          name: match[:name],
          title: og_data[:headline] || "No Title",
          author: og_data[:author],
          url: @url,
        }

        if keywords = og_data[:keywords]&.split(",")
          @data[:keywords] = keywords
            .map { |keyword| "<a href='https://gfycat.com/gifs/search/#{keyword}'>##{keyword}</a>" }
            .join(" ")
        end

        if og_data[:video]
          content_url = ::Onebox::Helpers.normalize_url_for_output(og_data[:video][:contentUrl])
          video_url = Pathname.new(content_url)
          @data[:webmUrl] = video_url.sub_ext(".webm").to_s
          @data[:mp4Url] = video_url.sub_ext(".mp4").to_s

          thumbnail_url = ::Onebox::Helpers.normalize_url_for_output(og_data[:video][:thumbnailUrl])
          @data[:posterUrl] = thumbnail_url

          @data[:width] = og_data[:video][:width]
          @data[:height] = og_data[:video][:height]
        end

        @data
      end
    end
  end
end
