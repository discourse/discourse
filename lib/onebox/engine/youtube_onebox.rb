# frozen_string_literal: true

module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://(?:www\.)?(?:m\.)?(?:youtube\.com|youtu\.be)/.+$})
      requires_iframe_origins "https://www.youtube.com"
      always_https

      WIDTH = 480
      HEIGHT = 360

      def parse_embed_response
        return unless video_id
        return @parse_embed_response if defined?(@parse_embed_response)

        embed_url = "https://www.youtube.com/embed/#{video_id}"
        @embed_doc ||= Onebox::Helpers.fetch_html_doc(embed_url)

        begin
          script_tag =
            @embed_doc.xpath("//script").find { |tag| tag.to_s.include?("ytcfg.set") }.to_s
          match = script_tag.to_s.match(/ytcfg\.set\((?<json>.*)\)/)

          yt_json = ::JSON.parse(match[:json])
          renderer =
            ::JSON.parse(yt_json["PLAYER_VARS"]["embedded_player_response"])["embedPreview"][
              "thumbnailPreviewRenderer"
            ]

          title = renderer["title"]["runs"].first["text"]

          image = "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"
        rescue StandardError
          return
        end

        @parse_embed_response = { image: image, title: title }
      end

      def placeholder_html
        if video_id || list_id
          result = parse_embed_response
          result ||= get_opengraph.data

          "<img src='#{result[:image]}' width='#{WIDTH}' height='#{HEIGHT}' title='#{CGI.escapeHTML(result[:title])}'>"
        else
          to_html
        end
      end

      def to_html
        if video_id
          <<-HTML
            <iframe
              src="https://www.youtube.com/embed/#{video_id}?#{embed_params}"
              width="#{WIDTH}"
              height="#{HEIGHT}"
              frameborder="0"
              allowfullscreen
              class="youtube-onebox"
            ></iframe>
          HTML
        elsif list_id
          <<-HTML
            <iframe
              src="https://www.youtube.com/embed/videoseries?list=#{list_id}&wmode=transparent&rel=0&autohide=1&showinfo=1&enablejsapi=1"
              width="#{WIDTH}"
              height="#{HEIGHT}"
              frameborder="0"
              allowfullscreen
              class="youtube-onebox"
            ></iframe>
          HTML
        else
          # for channel pages
          html = Onebox::Engine::AllowlistedGenericOnebox.new(@url, @timeout).to_html
          return if html.blank?
          html.gsub!(%r{['"]//}, "https://")
          html
        end
      end

      def video_title
        @video_title ||=
          begin
            result = parse_embed_response || get_opengraph.data
            result[:title]
          end
      end

      private

      def video_id
        @video_id ||=
          begin
            id = nil

            # http://youtu.be/afyK1HSFfgw
            id = uri.path[%r{/([\w\-]+)}, 1] if uri.host["youtu.be"]

            # https://www.youtube.com/embed/vsF0K3Ou1v0
            id ||= uri.path[%r{/embed/([\w\-]+)}, 1] if uri.path["/embed/"]

            # https://www.youtube.com/shorts/wi2jAtpBl0Y
            id ||= uri.path[%r{/shorts/([\w\-]+)}, 1] if uri.path["/shorts/"]

            # https://www.youtube.com/watch?v=Z0UISCEe52Y
            id ||= params["v"]

            sanitize_yt_id(id)
          end
      end

      def list_id
        @list_id ||= sanitize_yt_id(params["list"])
      end

      def sanitize_yt_id(raw)
        raw&.match?(/\A[\w-]+\z/) ? raw : nil
      end

      def embed_params
        p = { "feature" => "oembed", "wmode" => "opaque" }

        p["list"] = list_id if list_id

        # Parse timestrings, and assign the result as a start= parameter
        start =
          if params["start"]
            params["start"]
          elsif params["t"]
            params["t"]
          elsif uri.fragment && uri.fragment.start_with?("t=")
            # referencing uri is safe here because any throws were already caught by video_id returning nil
            # remove the t= from the start
            uri.fragment[2..-1]
          end

        p["start"] = parse_timestring(start) if start
        p["end"] = parse_timestring params["end"] if params["end"]

        # Official workaround for looping videos
        # https://developers.google.com/youtube/player_parameters#loop
        # use params.include? so that you can just add "&loop"
        if params.include?("loop")
          p["loop"] = 1
          p["playlist"] = video_id
        end

        # https://developers.google.com/youtube/player_parameters#rel
        p["rel"] = 0 if params.include?("rel")

        # https://developers.google.com/youtube/player_parameters#enablejsapi
        p["enablejsapi"] = params["enablejsapi"] if params.include?("enablejsapi")

        URI.encode_www_form(p)
      end

      def parse_timestring(string)
        ($1.to_i * 3600) + ($2.to_i * 60) + $3.to_i if string =~ /(\d+h)?(\d+m)?(\d+s?)?/
      end

      def params
        return {} unless uri.query
        # This mapping is necessary because CGI.parse returns a hash of keys to arrays.
        # And *that* is necessary because querystrings support arrays, so they
        # force you to deal with it to avoid security issues that would pop up
        # if one day it suddenly gave you an array.
        #
        # However, we aren't interested. Just take the first one.
        @params ||=
          begin
            p = {}
            CGI.parse(uri.query).each { |k, v| p[k] = v.first }
            p
          end
      rescue StandardError
        {}
      end
    end
  end
end
