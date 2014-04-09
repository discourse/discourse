module Onebox
  module Engine
    class VideoOnebox
      include Engine

      matches_regexp /^https?:\/\/.*\.mp3$/

      def to_html
        "<audio controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></audio>"
      end
    end
  end
end


