module Onebox
  module Engine
    class ClassicGoogleMapsOnebox
      include Engine
      include LayoutSupport

      matches_regexp /^(https?:)?\/\/(maps\.google\.[\w.]{2,}|goo\.gl)\/maps?.+$/

      def url
        @url.include?("//goo.gl/maps/") ? get_long_url : @url
      end

      def to_html
        "<iframe src='#{url}&output=embed' width='690px' height='400px' frameborder='0' style='border:0'></iframe>" 
      end

      def get_long_url
        uri = URI(@url)
        http = Net::HTTP.start(uri.host, uri.port)
        http.open_timeout = timeout
        http.read_timeout = timeout
        response = http.head(uri.path)
        response["Location"] if response.code == "301"
      rescue
        nil
      end

    end
  end
end
