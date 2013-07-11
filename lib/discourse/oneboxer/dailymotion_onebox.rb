module Discourse
	module Oneboxer
	  class DailymotionOnebox < OembedOnebox

	    matcher /^https?:\/\/(?:www\.)?dailymotion\.com\/.+$/

	    def oembed_endpoint
	      "http://www.dailymotion.com/api/oembed/?url=#{BaseOnebox.uriencode(@url)}"
	    end


	  end
	end
end