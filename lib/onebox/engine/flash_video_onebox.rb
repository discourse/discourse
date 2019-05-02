# frozen_string_literal: true

module Onebox
  module Engine
    class FlashVideoOnebox
      include Engine

      matches_regexp /^https?:\/\/.*\.(swf|flv)$/

      def to_html
        if SiteSetting.enable_flash_video_onebox
          "<object width='100%' height='100%'><param name='#{@url}' value='#{@url}'><embed src='#{@url}' width='100%' height='100%'></embed></object>"
        else
          "<a href='#{@url}'>#{@url}</a>"
        end
      end
    end
  end
end
