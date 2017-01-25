module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(?:www\.)?(?:m\.)?(?:youtube\.com|youtu\.be)\/.+$/)
      always_https

      WIDTH  ||= 480
      HEIGHT ||= 360

      def placeholder_html
        if video_id
          "<img src='https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg' width='#{WIDTH}' height='#{HEIGHT}' #{Helpers.title_attr(video_oembed_data)}>"
        elsif list_id
          "<img src='#{list_thumbnail_url}' width='#{WIDTH}' height='#{HEIGHT}' #{Helpers.title_attr(list_oembed_data)}>"
        else
          to_html
        end
      end

      def to_html
        if video_id
          <<-HTML
            <iframe width="#{WIDTH}"
                    height="#{HEIGHT}"
                    src="https://www.youtube.com/embed/#{video_id}?#{embed_params}"
                    frameborder="0"
                    allowfullscreen>
            </iframe>
          HTML
        elsif list_id
          <<-HTML
            <iframe width="#{WIDTH}"
                    height="#{HEIGHT}"
                    src="https://www.youtube.com/embed/videoseries?list=#{list_id}&wmode=transparent&rel=0&autohide=1&showinfo=1&enablejsapi=1"
                    frameborder="0"
                    allowfullscreen>
            </iframe>
          HTML
        else
          # for channel pages
          html = Onebox::Engine::WhitelistedGenericOnebox.new(@url, @cache, @timeout).to_html
          return if Onebox::Helpers.blank?(html)
          html.gsub!(/['"]\/\//, "https://")
          html
        end
      end

      def video_title
        @video_title ||= begin
          video_oembed_data[:title]
        rescue
          nil
        end
      end

      private

        def video_id
          @video_id ||= begin
            # http://youtu.be/afyK1HSFfgw
            if uri.host["youtu.be"]
              id = uri.path[/\/([\w\-]+)/, 1]
              return id if id
            end

            # https://www.youtube.com/embed/vsF0K3Ou1v0
            if uri.path["/embed/"]
              id = uri.path[/\/embed\/([\w\-]+)/, 1]
              return id if id
            end

            # https://www.youtube.com/watch?v=Z0UISCEe52Y
            params['v']
          end
        end

        def list_id
          @list_id ||= params['list']
        end

        def list_thumbnail_url
          @list_thumbnail_url ||= begin
            url = "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/playlist?list=#{list_id}"
            response = Onebox::Helpers.fetch_response(url) rescue "{}"
            data = Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
            data[:thumbnail_url]
          rescue
            nil
          end
        end

        def video_oembed_data
          url = "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=#{video_id}"
          response = Onebox::Helpers.fetch_response(url) rescue "{}"
          Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
        end

        def list_oembed_data
          url = "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/playlist?list=#{list_id}"
          response = Onebox::Helpers.fetch_response(url) rescue "{}"
          Onebox::Helpers.symbolize_keys(::MultiJson.load(response))
        end

        def embed_params
          p = {'feature' => 'oembed', 'wmode' => 'opaque'}

          p['list'] = list_id if list_id

          # Parse timestrings, and assign the result as a start= parameter
          start = if params['start']
            params['start']
          elsif params['t']
            params['t']
          elsif uri.fragment && uri.fragment.start_with?('t=')
            # referencing uri is safe here because any throws were already caught by video_id returning nil
            # remove the t= from the start
            uri.fragment[2..-1]
          end

          p['start'] = parse_timestring(start)        if start
          p['end']   = parse_timestring params['end'] if params['end']

          # Official workaround for looping videos
          # https://developers.google.com/youtube/player_parameters#loop
          # use params.include? so that you can just add "&loop"
          if params.include?('loop')
            p['loop'] = 1
            p['playlist'] = video_id
          end

          URI.encode_www_form(p)
        end

        def parse_timestring(string)
          if string =~ /(\d+h)?(\d+m)?(\d+s?)?/
            ($1.to_i * 3600) + ($2.to_i * 60) + $3.to_i
          end
        end

        def params
          return {} unless uri.query
          # This mapping is necessary because CGI.parse returns a hash of keys to arrays.
          # And *that* is necessary because querystrings support arrays, so they
          # force you to deal with it to avoid security issues that would pop up
          # if one day it suddenly gave you an array.
          #
          # However, we aren't interested. Just take the first one.
          @params ||= begin
            p = {}
            CGI.parse(uri.query).each { |k, v| p[k] = v.first }
            p
          end
        rescue
          {}
        end

    end
  end
end
