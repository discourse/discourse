# frozen_string_literal: true

module Onebox
  module Mixins
    module TwitchOnebox
      def self.included(klass)
        klass.include(Onebox::Engine)
        klass.matches_regexp(klass.twitch_regexp)
        klass.requires_iframe_origins "https://player.twitch.tv"
        klass.include(InstanceMethods)
      end

      module InstanceMethods
        def twitch_id
          @url.match(self.class.twitch_regexp)[1]
        end

        def base_url
          "player.twitch.tv/?"
        end

        def placeholder_html
          ::Onebox::Helpers.video_placeholder_html
        end

        def to_html
          <<~HTML
          <iframe src="https://#{base_url}#{query_params}&parent=#{Discourse.current_hostname}&autoplay=false" width="620" height="378" frameborder="0" style="overflow: hidden;" scrolling="no" allowfullscreen="allowfullscreen"></iframe>
          HTML
        end
      end
    end
  end
end
