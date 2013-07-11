require_dependency 'oneboxer/base_onebox'

module Oneboxer
  class FlashVideoOnebox < BaseOnebox
    
    matcher /^https?:\/\/.*\.(swf|flv)$/

    def onebox
      if SiteSetting.enable_flash_video_onebox
        "<object width='100%' height='100%'><param name='#{@url}' value='#{@url}'><embed src='#{@url}' width='100%' height='100%'></embed></object>"
      else
        "<a href='#{@url}'>#{@url}</a>"
      end
    end

  end
end
