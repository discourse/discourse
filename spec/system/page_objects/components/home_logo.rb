# frozen_string_literal: true

module PageObjects
  module Components
    class HomeLogo < PageObjects::Components::Base
      def has_dark_logo_forced?
        have_count(0).does_not_match?(browser_root.locator(".title picture source[media=\"all\"]"))
      end

      def has_light_logo_forced?
        have_count(0).does_not_match?(browser_root.locator(".title picture source[media=\"none\"]"))
      end

      def has_auto_color_mode?
        have_count(0).does_not_match?(
          browser_root.locator(".title picture source[media=\"(prefers-color-scheme: dark)\"]"),
        )
      end
    end
  end
end
