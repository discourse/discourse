# frozen_string_literal: true

module PageObjects
  module Pages
    class LovelaceChecklist < PageObjects::Pages::Base
      def open_admin
        visit("/admin/plugins/lovelace/checklist")
        self
      end

      def open_onboarding_tab
        click_link(I18n.t("js.lovelace.onboarding.title"), exact: true)
      end

      def open_checklist_tab
        click_link(I18n.t("js.lovelace.configure"), exact: true)
      end

      def has_onboarding_editor?
        has_css?(".lovelace-onboarding")
      end

      def open_member
        visit("/lovelace/checklist")
        self
      end

      def move_to_bank(id)
        within(".lovelace-checklist__selected [data-item-id='#{id}']") do
          click_button(I18n.t("js.lovelace.remove"))
        end
      end

      def add_to_checklist(id)
        within(".lovelace-checklist__bank [data-item-id='#{id}']") do
          click_button(I18n.t("js.lovelace.add"))
        end
      end

      def has_selected_item?(id)
        has_css?(".lovelace-checklist__selected [data-item-id='#{id}']")
      end

      def has_bank_item?(id)
        has_css?(".lovelace-checklist__bank [data-item-id='#{id}']")
      end

      def has_member_link?(label, path)
        has_link?(label, href: path)
      end
    end
  end
end
