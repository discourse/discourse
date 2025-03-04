# frozen_string_literal: true

module PageObjects
  module Components
    class HomeLogo < PageObjects::Components::Base
      def has_dark_logo_forced?
        has_css?(".title picture source[media=\"all\"]", visible: false)
      end

      def has_light_logo_forced?
        has_css?(".title picture source[media=\"none\"]", visible: false)
      end

      def has_auto_color_mode?
        has_css?(".title picture source[media=\"(prefers-color-scheme: dark)\"]", visible: false)
      end
    end
  end
end
