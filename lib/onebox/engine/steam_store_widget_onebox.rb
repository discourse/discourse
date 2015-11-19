module Onebox
  module Engine
    class SteamStoreWidgetOnebox
      include Engine
      
      matches_regexp(/^(https?:\/\/)?([\da-z\.-]+)(steampowered.com\/)(.)+\/?$/)

      # DoTheSimplestThingThatCouldPossiblyWork
      def to_html
        # Use the Steam support iframe widget over https
        widget_url = @url.gsub('/app/','/widget/')
        widget_url = widget_url.gsub('http:','https:')
        "<iframe class='steamstorewidget' src='#{widget_url}' frameborder='0' width='100%' height='190'></iframe>"
      rescue
        @url
      end

      # Placeholder is called at each interaction with editor, so do something less iframey
      def placeholder_html        
        widget_url = @url.gsub('/app/','/widget/')
        widget_url = widget_url.gsub('http:','https:')
        "<div style='width:100%; height:190px; display:block; background-color:black; color:white;'><div style='padding:10px;'><h2>Steam Store Widget onebox preview for: #{widget_url}</h2><p>Will be replaced with the real listing when posted.</p></div></div>"
      rescue
        @url
      end
      
    end
  end
end