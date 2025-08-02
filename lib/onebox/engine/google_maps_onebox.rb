# frozen_string_literal: true

module Onebox
  module Engine
    class GoogleMapsOnebox
      include Engine

      class << self
        def ===(other)
          if other.kind_of? URI
            @@matchers && @@matchers.any? { |m| other.to_s =~ m[:regexp] }
          else
            super
          end
        end

        private

        def matches_regexp(key, regexp)
          (@@matchers ||= []) << { key: key, regexp: regexp }
        end
      end

      always_https
      requires_iframe_origins("https://maps.google.com", "https://google.com")

      # Matches shortened Google Maps URLs
      matches_regexp :short, %r{^(https?:)?//goo\.gl/maps/}

      # Matches URLs for custom-created maps
      matches_regexp :custom,
                     %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps/d/(?:edit|viewer|embed)\?mid=.+$"

      # Matches URLs with streetview data
      matches_regexp :streetview,
                     %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps[^@]+@(?<lon>-?[\d.]+),(?<lat>-?[\d.]+),(?:\d+)a,(?<zoom>[\d.]+)y,(?<heading>[\d.]+)h,(?<pitch>[\d.]+)t.+?data=.*?!1s(?<pano>[^!]{22})"

      # Matches "normal" Google Maps URLs with arbitrary data
      matches_regexp :standard, %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps"

      # Matches URLs for the old Google Maps domain which we occasionally get redirected to
      matches_regexp :canonical, %r"^(?:https?:)?//maps\.google(?:\.(?:\w{2,}))+/maps\?"

      def initialize(url, timeout = nil)
        super
        resolve_url!
      rescue Net::HTTPServerException,
             Timeout::Error,
             Net::HTTPError,
             Errno::ECONNREFUSED,
             RuntimeError => err
        raise ArgumentError, "malformed url or unresolveable: #{err.message}"
      end

      def streetview?
        !!@streetview
      end

      def to_html
        "<div class='maps-onebox'><iframe src=\"#{link}\" width=\"690\" height=\"400\" frameborder=\"0\" style=\"border:0\">#{placeholder_html}</iframe></div>"
      end

      def placeholder_html
        ::Onebox::Helpers.map_placeholder_html
      end

      private

      def data
        { link: url, title: url }
      end

      def resolve_url!
        @streetview = false
        type, match = match_url

        # Resolve shortened URL, if necessary
        if type == :short
          follow_redirect!
          type, match = match_url
        end

        # Try to get the old-maps URI, it is far easier to embed.
        if type == :standard
          retry_count = 10
          while (retry_count -= 1) > 0
            follow_redirect!
            type, match = match_url
            break if type != :standard
            sleep 0.1
          end
        end

        case type
        when :standard
          # Fallback for map URLs that don't resolve into an easily embeddable old-style URI
          # Roadmaps use a "z" zoomlevel, satellite maps use "m" the horizontal width in meters
          # TODO: tilted satellite maps using "a,y,t"
          match = @url.match(/@(?<lon>[\d.-]+),(?<lat>[\d.-]+),(?<zoom>\d+)(\.\d+)?(?<mz>[mz])/)
          raise "unexpected standard url #{@url}" unless match
          zoom = match[:mz] == "z" ? match[:zoom] : Math.log2(57280048.0 / match[:zoom].to_f).round
          location = "#{match[:lon]},#{match[:lat]}"
          url = "https://maps.google.com/maps?ll=#{location}&z=#{zoom}&output=embed&dg=ntvb"
          url += "&q=#{$1}" if match = @url.match(%r{/place/([^/\?]+)})
          url += "&cid=#{($1 + $2).to_i(16)}" if @url.match(/!3m1!1s0x(\h{16}):0x(\h{16})/)
          @url = url
          @placeholder =
            "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&center=#{location}&zoom=#{zoom}&size=690x400&sensor=false"
        when :custom
          url = @url.dup
          @url = rewrite_custom_url(url, "embed")
          @placeholder = rewrite_custom_url(url, "thumbnail")
          @placeholder_height = @placeholder_width = 120
        when :streetview
          @streetview = true
          panoid = match[:pano]
          lon = match[:lon].to_f.to_s
          lat = match[:lat].to_f.to_s
          heading = match[:heading].to_f.round(4).to_s
          pitch = (match[:pitch].to_f / 10.0).round(4).to_s
          fov = (match[:zoom].to_f / 100.0).round(4).to_s
          zoom = match[:zoom].to_f.round
          @url =
            "https://www.google.com/maps/embed?pb=!3m2!2sen!4v0!6m8!1m7!1s#{panoid}!2m2!1d#{lon}!2d#{lat}!3f#{heading}!4f#{pitch}!5f#{fov}"
          @placeholder =
            "https://maps.googleapis.com/maps/api/streetview?size=690x400&location=#{lon},#{lat}&pano=#{panoid}&fov=#{zoom}&heading=#{heading}&pitch=#{pitch}&sensor=false"
        when :canonical
          query = URI.decode_www_form(uri.query).to_h
          if !query.has_key?("ll")
            unless query.has_key?("sll")
              raise ArgumentError, "canonical url lacks location argument"
            end
            query["ll"] = query["sll"]
            @url += "&ll=#{query["sll"]}"
          end
          location = query["ll"]
          if !query.has_key?("z")
            unless query.has_key?("spn") || query.has_key?("sspn")
              raise ArgumentError, "canonical url has incomplete query arguments"
            end
            if !query.has_key?("spn")
              query["spn"] = query["sspn"]
              @url += "&spn=#{query["sspn"]}"
            end
            angle = query["spn"].split(",").first.to_f
            zoom = (Math.log(690.0 * 360.0 / angle / 256.0) / Math.log(2)).round
          else
            zoom = query["z"]
          end
          @url = @url.sub("output=classic", "output=embed")
          @placeholder =
            "https://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&size=690x400&sensor=false&center=#{location}&zoom=#{zoom}"
        else
          raise "unexpected url type #{type.inspect}"
        end
      end

      def match_url
        @@matchers.each do |matcher|
          if m = matcher[:regexp].match(@url)
            return matcher[:key], m
          end
        end
        raise ArgumentError, "\"#{@url}\" does not match any known pattern"
      end

      def rewrite_custom_url(url, target)
        uri = URI(url)
        uri.path = uri.path.sub(%r{(?<=^/maps/d/)\w+$}, target)
        uri.to_s
      end

      def follow_redirect!
        begin
          http =
            FinalDestination::HTTP.start(
              uri.host,
              uri.port,
              use_ssl: uri.scheme == "https",
              open_timeout: timeout,
              read_timeout: timeout,
            )

          response = http.head(uri.path)
          if %w[200 301 302].exclude?(response.code)
            raise "unexpected response code #{response.code}"
          end

          @url = response.code == "200" ? uri.to_s : response["Location"]
          @uri = URI(@url)
        ensure
          begin
            http.finish
          rescue StandardError
            nil
          end
        end
      end
    end
  end
end
