# frozen_string_literal: true

module PageObjects
  module Components
    class InterfaceColorMode < PageObjects::Components::Base
      def has_light_mode_forced?
        has_light_scheme_with_media?("all") && has_dark_scheme_with_media?("none")
      end

      def has_dark_mode_forced?
        has_light_scheme_with_media?("none") && has_dark_scheme_with_media?("all")
      end

      def has_auto_color_mode?
        has_light_scheme_with_media?("(prefers-color-scheme: light)") &&
          has_dark_scheme_with_media?("(prefers-color-scheme: dark)")
      end

      private

      def has_light_scheme_with_media?(media)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("link.light-scheme[media=\"#{media}\"]"),
        )
      end

      def has_dark_scheme_with_media?(media)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("link.dark-scheme[media=\"#{media}\"]"),
        )
      end
    end
  end
end
