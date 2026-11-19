# frozen_string_literal: true

module PageObjects
  module Modals
    class Badge < PageObjects::Pages::Base
      GRANTABLE_BADGES_DROPDOWN = ".select-kit"

      def modal
        find(".grant-badge-modal")
      end

      def select_badge(badge_name)
        return badge_select.select_name(badge_name) if SiteSetting.enable_new_select_controls

        within(modal) do
          grantable_badges_dropdown.expand
          grantable_badges_dropdown.select_row_by_name(badge_name)
        end
      end

      def badge_select
        PageObjects::Components::UiKit::DSelect.by_identifier("grant-badge")
      end

      def has_badge_description?(name, description)
        badge_select.open
        has_css?(
          "#{badge_select.option_selector}[data-name='#{name}'] .d-select__option-description",
          exact_text: description,
        )
      end

      def grant
        within(modal) { find(".d-modal__footer .btn").click }
      end

      def has_no_none_option?
        has_no_css?("#{badge_select.option_selector}.--none")
      end

      def has_grant_enabled?
        within(modal) { has_css?(".d-modal__footer .btn-primary:not([disabled])") }
      end

      def has_grant_disabled?
        within(modal) { has_css?(".d-modal__footer .btn-primary[disabled]") }
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
