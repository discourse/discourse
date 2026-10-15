# frozen_string_literal: true

module PageObjects
  module Modals
    class Badge < PageObjects::Pages::Base
      GRANTABLE_BADGES_DROPDOWN = ".select-kit"

      def modal
        browser_root.locator(".grant-badge-modal").filter(visible: true)
      end

      def select_badge(badge_name)
        within_browser(modal) do
          grantable_badges_dropdown.expand
          grantable_badges_dropdown.select_row_by_name(badge_name)
        end
      end

      def grant
        within_browser(modal) do
          browser_root.locator(".d-modal__footer .btn").filter(visible: true).click
        end
      end

      def has_success_flash_visible?
        within_browser(modal) do
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".alert-success").filter(visible: true),
          )
        end
      end

      def grantable_badges_dropdown
        @grantable_badges_dropdown ||=
          PageObjects::Components::SelectKit.new(GRANTABLE_BADGES_DROPDOWN)
      end
    end
  end
end
