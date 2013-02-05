require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class ImageOnebox < BaseOnebox

    matcher /^https?:\/\/.*\.(jpg|png|gif|jpeg)$/

    def onebox
      "<a href='#{@url}' target='_blank'><img src='#{@url}'></a>"
    end

  end
end
