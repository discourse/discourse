# frozen_string_literal: true

module Onebox
  module Mixins
    module TwitchOnebox

      def self.included(klass)
        klass.include(Onebox::Engine)
        klass.matches_regexp(klass.twitch_regexp)
        klass.include(InstanceMethods)
      end

      module InstanceMethods
        def twitch_id
          @url.match(self.class.twitch_regexp)[1]
        end

        def base_url
          "player.twitch.tv/?"
        end

        def to_html
          "<iframe src=\"//#{base_url}#{query_params}&autoplay=false\" width=\"620\" height=\"378\" frameborder=\"0\" style=\"overflow: hidden;\" scrolling=\"no\" allowfullscreen=\"allowfullscreen\"></iframe>"
        end
      end
    end
  end
end
