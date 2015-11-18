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

    end
  end
end