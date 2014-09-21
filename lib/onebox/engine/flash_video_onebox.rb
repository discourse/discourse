module Onebox
  module Engine
    class FlashVideoOnebox
      include Engine

      matches_regexp /^https?:\/\/.*\.(swf|flv)(#(\d{1,4}x\d{1,4}))?$/

      def to_html
        # Lidlanca 2014
        # Support size from url http://matching.domain/file.swf#WxH
        # Providing 0 in a dimension (W|H) to indicate 100%
        m = @url.match /^(?<url>https?:\/\/.*\.(swf|flv))(#(?<width>\d{1,4})x(?<height>\d{1,4}))?$/
        max_w = 1000
        min_w = 100  
        max_h = 1000
        min_h = 100

        style = ""
        if m["width"] && m["height"]  #size provided
          style = ["max-width:100%","max-height:100%"]             #prevent overflow of parent container
          url_width  = [[m["width"].to_i,max_w].min(),min_w].max   #make sure min_w < url_width < max_w
          url_height = [[m["height"].to_i,max_h].min(),min_h].max  #make sure min_h < url_height < max_h
          style <<  (m["width"].to_i == 0  ? "width:100%"  : "width:#{url_width}px")
          style <<  (m["height"].to_i == 0 ? "height:100%" : "height:#{url_height}px")
          style = style.join ";"
        end
        @url = m["url"]

        if SiteSetting.enable_flash_video_onebox
          "<object style=\"#{style}\" width='100%' height='100%'><param name='#{@url}' value='#{@url}'><embed src='#{@url}' style=\"#{style}\" width='100%' height='100%'></embed></object>"
        else
          "<a href='#{@url}'>#{@url}</a>"
        end
      end
    end
  end
end
