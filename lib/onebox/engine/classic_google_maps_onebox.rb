module Onebox
  module Engine
    class ClassicGoogleMapsOnebox
      include Engine
      include LayoutSupport

      matches_regexp /^(https?:)?\/\/(maps\.google\.[\w.]{2,}|goo\.gl)\/maps?.+$/

      def url
        @url = get_long_url if @url.include?("//goo.gl/maps/") 
        @url
      end

      def to_html
        "<iframe src='#{url}&output=embed' width='690px' height='400px' frameborder='0' style='border:0'></iframe>" 
      end

      private 

      def data
        {link: url, title: url}
      end

      def get_long_url
        uri = URI(@url)
        http = Net::HTTP.start(uri.host, uri.port)
        http.open_timeout = timeout
        http.read_timeout = timeout
        response = http.head(uri.path)
        response["Location"] if response.code == "301"
      rescue
        @url
      end

    end
  end
end
