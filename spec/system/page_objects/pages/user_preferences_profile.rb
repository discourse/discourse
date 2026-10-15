# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesProfile < PageObjects::Pages::Base
      def visit(user)
        browser_page
          .goto("/u/#{user.username}/preferences/profile")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def hide_profile
        browser_root.locator(".user-hide-profile .pref-hide-profile").filter(visible: true).click
      end

      def has_hidden_profile?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            ".user-hide-profile .pref-hide-profile input[type=checkbox]:checked",
          ).filter(visible: true),
        )
      end

      def expand_profile_details
        browser_root
          .locator(".user-main .details .controls .btn-default")
          .filter(visible: true)
          .click
      end

      def fill_bio(with:)
        browser_root.locator(".bio-composer .d-editor-input").filter(visible: true).fill(with)
      end

      def save
        browser_root.locator(".save-button .btn-primary").filter(visible: true).click
      end

      def cooked_bio
        browser_root.locator(".user-main .details .primary .bio").filter(visible: true)
      end
    end
  end
end
