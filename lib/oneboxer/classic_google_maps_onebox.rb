require 'net/http'
require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class ClassicGoogleMapsOnebox < BaseOnebox

    matcher /^(https?:)?\/\/(maps\.google\.[\w.]{2,}|goo\.gl)\/maps?.+$/

    def onebox
      @url = get_long_url(@url) if @url.include?("//goo.gl/maps/")
      "<iframe src='#{@url}&output=embed' width='690px' height='400px' frameborder='0' style='border:0'></iframe>" if @url.present?
    end

    def get_long_url(url)
      uri = URI(url)
      http = Net::HTTP.start(uri.host, uri.port)
      http.open_timeout = 1
      http.read_timeout = 1
      response = http.head(uri.path)
      response["Location"] if response.code == "301"
    rescue
      nil
    end

  end
end
