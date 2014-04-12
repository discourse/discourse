module Onebox
  module Engine
    class ImageOnebox
      include Engine

      matches_regexp /^(https?:)?\/\/.+\.(png|jpg|jpeg|gif|bmp|tif|tiff)(\?.*)?$/i

      def to_html
        "<a href='#{@url}' target='_blank'><img src='#{@url}'></a>"
      end
    end
  end
end
