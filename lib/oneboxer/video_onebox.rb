require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class VideoOnebox < BaseOnebox
    
    matcher /^https?:\/\/.*\.(mov|mp4)$/

    def onebox
      "<video controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></video>"
    end

  end
end
