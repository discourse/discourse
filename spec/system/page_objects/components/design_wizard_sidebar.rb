# frozen_string_literal: true

module PageObjects
  module Components
    class DesignWizardSidebar < PageObjects::Components::Base
      WIZARD_SELECTOR = ".sidebar-design-wizard"

      def visible?
        has_css?(WIZARD_SELECTOR)
      end

      def hidden?
        has_no_css?(WIZARD_SELECTOR)
      end

      def has_theme_modal?
        has_css?(".theme-picker-modal")
      end

      def has_no_theme_modal?
        has_no_css?(".theme-picker-modal")
      end

      def choose_theme(name)
        find(".theme-picker-modal__card", text: name).click
      end

      def continue_from_theme_modal
        find(".theme-picker-modal__footer .btn-primary").click
      end

      def select_palette(pair_key)
        find("#{WIZARD_SELECTOR} .design-wizard-modal__swatch[data-pair-key='#{pair_key}']").click
      end

      def toggle_user_selectable_palettes
        find("#{WIZARD_SELECTOR} .design-wizard-modal__user-selectable").click
      end

      def select_body_font(font_key)
        groups = all("#{WIZARD_SELECTOR} .design-wizard-modal__font-group")
        groups[0].find(".design-wizard-modal__font-card.body-font-#{font_key.tr("_", "-")}").click
      end

      def has_palette_preview?
        has_css?("link#design-wizard-preview-scheme", visible: :all)
      end

      def has_no_palette_preview?
        has_no_css?("link#design-wizard-preview-scheme", visible: :all)
      end

      def next_step
        find("#{WIZARD_SELECTOR}__next").click
      end

      def back
        find("#{WIZARD_SELECTOR}__back").click
      end

      def save
        find("#{WIZARD_SELECTOR}__save").click
      end

      def close
        find(".design-wizard-float__close").click
      end
    end
  end
end
