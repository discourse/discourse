# frozen_string_literal: true

module PageObjects
  module Modals
    class Badge < PageObjects::Pages::Base
      GRANTABLE_BADGES_DROPDOWN = ".select-kit"

      def modal
        find(".grant-badge-modal")
      end

      def select_badge(badge_name)
        within(modal) do
          grantable_badges_dropdown.expand
          grantable_badges_dropdown.select_row_by_name(badge_name)
        end
      end

      def grant
        within(modal) { find(".d-modal__footer .btn").click }
      end

      def has_success_flash_visible?
        within(modal) { has_css?(".alert-success") }
      end

      def grantable_badges_dropdown
        @grantable_badges_dropdown ||=
          PageObjects::Components::SelectKit.new(GRANTABLE_BADGES_DROPDOWN)
      end
    end
  end
end
