module Onebox
  module Engine
    class YoutubeOnebox
      include Engine
      include StandardEmbed

      matches_regexp(/^https?:\/\/(?:www\.)?(?:m\.)?(?:youtube\.com|youtu\.be)\/.+$/)
      always_https

      # Try to get the video ID. Works for URLs of the form:
      # * https://www.youtube.com/watch?v=Z0UISCEe52Y
      # * http://youtu.be/afyK1HSFfgw
      # * https://www.youtube.com/embed/vsF0K3Ou1v0
      def video_id
        if uri.host =~ /youtu.be/
          # A slash, then capture all non-slash characters remaining
          match = uri.path.match(/\/([^\/]+)/)
          return match[1] if match && match[1]
        end

        if uri.path =~ /\/embed\//
          # A slash, then embed, then anotther slash, then capture all remaining non-slash characters
          match = uri.path.match(/\/embed\/([^\/]+)/)
          return match[1] if match && match[1]
        end

        if params['v']
          return params['v']
        end

        nil
      rescue
        return nil
      end

      def placeholder_html
        if video_id
          "<img src='https://i1.ytimg.com/vi/#{video_id}/hqdefault.jpg' width='480' height='270'>"
        else
          to_html
        end
      end

      def to_html
        if video_id
          # Avoid making HTTP requests if we are able to get the video ID from the
          # URL.
          html = "<iframe width=\"480\" height=\"270\" src=\"https://www.youtube.com/embed/#{video_id}?#{embed_params}\" frameborder=\"0\" allowfullscreen></iframe>"
        else
          # for channel pages
          html = Onebox::Engine::WhitelistedGenericOnebox.new(@url, @cache, @timeout).to_html
          return nil unless html
          html = html.gsub /http:/, 'https:'
          html = html.gsub /"\/\//, '"https://'
          html = html.gsub /'\/\//, "'https://"
        end

        html
      end

      def video_title
        yt_oembed_url = "https://www.youtube.com/oembed?format=json&url=https://www.youtube.com/watch?v=#{video_id.split('?')[0]}"
        yt_oembed_data = Onebox::Helpers.symbolize_keys(::MultiJson.load(Onebox::Helpers.fetch_response(yt_oembed_url).body))
        yt_oembed_data[:title]
      rescue
        return nil
      end

      # Regex to parse strings like "1h3m2s". Also accepts bare numbers (which are seconds).
      TIMESTR_REGEX = /(\d+h)?(\d+m)?(\d+s?)?/

      def embed_params
        p = {'feature' => 'oembed', 'wmode' => 'opaque'}

        p['list'] = params['list'] if params['list']

        # Parse timestrings, and assign the result as a start= parameter
        start = nil
        if params['start']
          start = params['start']
        elsif params['t']
          start = params['t']
        elsif uri.fragment && uri.fragment.start_with?('t=')
          # referencing uri is safe here because any throws were already caught by video_id returning nil
          # remove the t= from the start
          start = uri.fragment[2..-1]
        end
        p['start'] = parse_timestring(start) if start
        p['end'] = parse_timestring params['end'] if params['end']

        # Official workaround for looping videos
        # https://developers.google.com/youtube/player_parameters#loop
        # use params.include? so that you can just add "&loop"
        if params.include? 'loop'
          p['loop'] = 1
          p['playlist'] = video_id
        end

        URI.encode_www_form(p)
      end

      private

      # Takes a timestring and returns the number of seconds it represents.
      def parse_timestring(string)
        tm = string.match TIMESTR_REGEX
        if tm && !tm[0].empty?
          h = tm[1].to_i
          m = tm[2].to_i
          s = tm[3].to_i

          (h * 60 * 60) + (m * 60) + s
        else
          nil
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
        @_params ||= begin
                       params = {}
                       CGI.parse(uri.query).each do |k, v|
                         params[k] = v.first
                       end
                       params
        end
      rescue
        return {}
      end

    end
  end
end
