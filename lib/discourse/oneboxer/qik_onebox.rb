module Discourse
	module Oneboxer
	  class QikOnebox < OembedOnebox

	    matcher /^https?\:\/\/qik\.com\/video\/.*$/

	    def oembed_endpoint
	      "http://qik.com/api/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
	    end

	  end
	end
end