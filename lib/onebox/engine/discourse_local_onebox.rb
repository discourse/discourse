require_relative 'discourse_local_onebox/choose_renderer'

module Onebox
  module Engine
    class DiscourseLocalOnebox
      include Engine

      matches_regexp Regexp.new("^#{Discourse.base_url.gsub(".","\\.")}.*$", true)

      # Use this onebox before others
      def self.priority
        1
      end

      def to_html
        if renderer = ChooseRenderer.call(url: @url)
          renderer.call
        end
      end

    end
  end
end
