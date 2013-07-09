require_dependency 'oneboxer/oembed_onebox'

module Oneboxer
  class CollegeHumorOnebox < OembedOnebox

    matcher /^https?\:\/\/www\.collegehumor\.com\/video\/.*$/

    def oembed_endpoint
      "http://www.collegehumor.com/oembed.json?url=#{BaseOnebox.uriencode(@url)}"
    end


  end
end
