module Onebox
  module Engine
    class GoogleMapsOnebox
      include Engine

      class << self
        def ===(other)
          if other.kind_of? URI
            @@matchers && @@matchers.any? {|m| other.to_s =~ m[:regexp] }
          else
            super
          end
        end

        private

        def matches_regexp(key, regexp)
          (@@matchers ||= []) << {key: key, regexp: regexp}
        end
      end

      matches_regexp :short,      %r"^(https?:)?//goo\.gl/maps/"
      matches_regexp :custom,     %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps/d/(?:edit|viewer|embed)\?mid=.+$"
      matches_regexp :streetview, %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps[^@]+@(?<lon>[\d.]+),(?<lat>[\d.]+),(?:\d+)a,(?<zoom>[\d.]+)y,(?<heading>[\d.]+)h,(?<pitch>[\d.]+)t.+?data=.*?!1s(?<pano>[^!]{22})"
      matches_regexp :classic,    %r"^(?:https?:)?//www\.google(?:\.(?:\w{2,}))+/maps"
      matches_regexp :canonical,  %r"^(?:https?:)?//maps\.google(?:\.(?:\w{2,}))+/maps\?"

      def initialize(url, cache = nil, timeout = nil)
        super
        resolve_url!
      rescue Net::HTTPServerException, Timeout::Error, Net::HTTPError, Errno::ECONNREFUSED, RuntimeError => err
        raise ArgumentError, "malformed url or unresolveable: #{err.message}"
      end

      def streetview?
        @streetview
      end

      def to_html
        Helpers.click_to_scroll_div + "<iframe src=\"#{link}\" width=\"690\" height=\"400\" frameborder=\"0\" style=\"border:0\"></iframe>"
      end

      def placeholder_html
        width = @placeholder_width || 690
        height = @placeholder_height || 400
        "<img src=\"#{CGI.escapeHTML(@placeholder)}\" width=\"#{width}\" height=\"#{height}\"/>"
      end

      private

      def data
        { link: url, title: url }
      end

      def resolve_url!
        @streetview = false
        type = find_url_type!

        if type == :short
          follow_redirect!
          type = find_url_type!
        end

        if type == :classic
          follow_redirect!
          type = find_url_type!
        end

        case type
        when :short then raise "unexpected short url"
        when :classic then raise "unexpected classic url"

        when :custom
          url = @url.dup
          @url = rewrite_custom_url(url, "embed")
          @placeholder = rewrite_custom_url(url, "thumbnail")
          @placeholder_height = @placeholder_width = 120

        when :streetview
          @streetview = true
          panoid = @match[:pano]
          lon = @match[:lon].to_f.to_s
          lat = @match[:lat].to_f.to_s
          heading = @match[:heading].to_f.round(4).to_s
          pitch = (@match[:pitch].to_f / 10.0).round(4).to_s
          fov = (@match[:zoom].to_f / 100.0).round(4).to_s
          @url = "https://www.google.com/maps/embed?pb=!3m2!2sen!4v0!6m8!1m7!1s#{panoid}!2m2!1d#{lon}!2d#{lat}!3f#{heading}!4f#{pitch}!5f#{fov}"
          @placeholder = "http://maps.googleapis.com/maps/api/streetview?size=690x400&location=#{lon},#{lat}&pano=#{panoid}&fov=#{@match[:zoom].to_f.round}&heading=#{heading}&pitch=#{pitch}&sensor=false"

        when :canonical
          uri = URI(@url)
          query = Hash[*uri.query.split("&").map{|a|a.split("=")}.flatten]
          unless (query.has_key?("spn") || query.has_key?("sspn")) && (query.has_key?("ll") || query.has_key?("sll"))
            raise ArgumentError, "canonical url has incomplete query parameters"
          end
          @url += "&ll=#{query["sll"]}" if !query["ll"]
          @url += "&spn=#{query["sspn"]}" if !query["spn"]
          @url = @url.sub('output=classic', 'output=embed')
          angle = (query["spn"] || query["sspn"]).split(",").first.to_f
          zoom = (Math.log(690.0 * 360.0 / angle / 256.0) / Math.log(2)).round
          @placeholder = "http://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&size=690x400&sensor=false&center=#{query["ll"] || query["sll"]}&zoom=#{zoom}"

        else
          raise "unexpected url type"
        end
      end

      def find_url_type!
        @@matchers.each do |matcher|
          if m = matcher[:regexp].match(@url)
            type, @match = matcher[:key], m
            return type
          end
        end
        raise ArgumentError, "\"#{url}\" does not match any known pattern"
      end

      def rewrite_custom_url(url, target)
        uri = URI(url)
        uri.path = uri.path.sub(/(?<=^\/maps\/d\/)\w+$/, target)
        uri.to_s
      end

      def follow_redirect!
        uri = URI(@url)
        http = Net::HTTP.start(uri.host, uri.port,
          use_ssl: uri.scheme == 'https', open_timeout: timeout, read_timeout: timeout)
        response = http.head(uri.path)
        raise "unexpected response code #{response.code}" unless %w(301 302).include?(response.code)
        @url = response["Location"]
      end

    end
  end
end
