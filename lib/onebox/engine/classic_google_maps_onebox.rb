module Onebox
  module Engine
    class ClassicGoogleMapsOnebox
      include Engine

      matches_regexp /^(https?:)?\/\/((maps|www)\.google\.[\w.]{2,}|goo\.gl)\/maps?.+$/

      def initialize(link, cache = nil, timeout = nil)
        super(link, cache, timeout)
        resolve_url!
      end

      def to_html
        "<iframe src=\"#{link}\" width=\"690px\" height=\"400px\" frameborder=\"0\" style=\"border:0\"></iframe>"
      end

      def placeholder_html
        return to_html unless @placeholder
        "<img src=\"http://maps.googleapis.com/maps/api/staticmap?maptype=roadmap&size=690x400&sensor=false&#{@placeholder}\" width=\"690\" height=\"400\"/>"
      end

      private

      def resolve_url!
        @url = follow_redirect(@url) if @url.include?("//goo.gl/maps")
        if m = @url.match(/@([-.\d]+,[-.\d]+),(\d+)z/)
          @placeholder = "center=#{m[1]}&zoom=#{m[2]}"
        end

        @url = follow_redirect(@url) if @url.include?("www.google")
        query = Hash[*URI(@url).query.split("&").map{|a|a.split("=")}.flatten]
        @url += "&ll=#{query["sll"]}" if !query["ll"]
        @url += "&spn=#{query["sspn"]}" if !query["spn"]
        if !@placeholder
          angle = (query["spn"] || query["sspn"]).split(",").first.to_f
          zoom = (Math.log(690.0 * 360.0 / angle / 256.0) / Math.log(2)).round
          @placeholder = "center=#{query["ll"] || query["sll"]}&zoom=#{zoom}"
        end

        @url = (@url =~ /output=classic/) ?
          @url.sub('output=classic', 'output=embed') :
          @url + '&output=embed'
      end

      def data
        {link: url, title: url}
      end

      def follow_redirect(link)
        uri = URI(link)
        http = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https')
        http.open_timeout = timeout
        http.read_timeout = timeout
        response = http.head(uri.path)
        response["Location"] if %(301 302).include?(response.code)
      rescue
        link
      end

    end
  end
end
