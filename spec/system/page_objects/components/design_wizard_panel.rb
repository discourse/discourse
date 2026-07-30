# frozen_string_literal: true

module PageObjects
  module Components
    class DesignWizardPanel < PageObjects::Components::Base
      WIZARD_SELECTOR = ".design-wizard"

      def visible?
        has_css?(WIZARD_SELECTOR)
      end

      def hidden?
        has_no_css?(WIZARD_SELECTOR)
      end

      def has_site_sidebar?
        has_css?(".sidebar-sections")
      end

      def select_theme(theme_id)
        find("#{WIZARD_SELECTOR}__theme-card[data-theme-id='#{theme_id}']").click
      end

      def has_selected_theme?(theme)
        has_css?(
          "#{WIZARD_SELECTOR}__theme-card[data-theme-id='#{theme.id}'] input[type='radio']:checked",
        )
      end

      def select_palette(pair_key)
        find("#{WIZARD_SELECTOR}__swatch[data-pair-key='#{pair_key}']").click
      end

      def toggle_user_selectable_palettes
        PageObjects::Components::DToggleSwitch.new(
          "#{WIZARD_SELECTOR}__user-selectable [role='switch']",
        ).toggle
      end

      def select_homepage(key)
        find("#{WIZARD_SELECTOR}__homepage-card[data-homepage='#{key}']").click
      end

      def select_body_font(font_key)
        groups = all("#{WIZARD_SELECTOR}__font-group")
        groups[0].find("#{WIZARD_SELECTOR}__font-select").click
        find(
          "[data-identifier='design-wizard-base-font'] .btn.body-font-#{font_key.tr("_", "-")}",
        ).click
      end

      def has_palette_preview?
        has_css?("link[data-scheme-id]", visible: :all)
      end

      def has_no_palette_preview?
        has_no_css?("link[data-scheme-id]", visible: :all)
      end

      def next_step
        find("#{WIZARD_SELECTOR}__next").click
      end

      def save
        find("#{WIZARD_SELECTOR}__save").click
      end

      def close
        find("#{WIZARD_SELECTOR}__close").click
      end
    end
  end
end
