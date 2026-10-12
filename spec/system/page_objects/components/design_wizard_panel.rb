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

      def has_no_selected_theme?
        has_no_css?("#{WIZARD_SELECTOR}__theme-card input[type='radio']:checked")
      end

      def has_disabled_next?
        has_css?("#{WIZARD_SELECTOR}__next[disabled]")
      end

      def select_palette(pair_key)
        find("#{WIZARD_SELECTOR}__swatch[data-pair-key='#{pair_key}']").click
      end

      def toggle_user_selectable_palettes
        user_selectable_switch.toggle
      end

      def has_user_selectable_palettes?
        user_selectable_switch.checked?
      end

      def has_no_user_selectable_palettes?
        user_selectable_switch.unchecked?
      end

      def select_homepage(key)
        find("#{WIZARD_SELECTOR}__homepage-card[data-homepage='#{key}']").click
      end

      def toggle_welcome_banner
        welcome_banner_switch.toggle
      end

      def has_welcome_banner_enabled?
        welcome_banner_switch.checked?
      end

      def has_no_welcome_banner_enabled?
        welcome_banner_switch.unchecked?
      end

      def select_welcome_banner_location(key)
        find("#{WIZARD_SELECTOR}__option-row[data-welcome-banner-location='#{key}']").click
      end

      def select_search_experience(key)
        find("#{WIZARD_SELECTOR}__option-row[data-search-experience='#{key}']").click
      end

      def select_body_font(font_key)
        groups = all("#{WIZARD_SELECTOR}__font-group")
        groups[0].find("#{WIZARD_SELECTOR}__font-select").click
        find(
          "[data-identifier='design-wizard-base-font'] .btn.body-font-#{font_key.tr("_", "-")}",
        ).click
      end

      def has_palette_preview?
        has_css?("link[data-scheme-preview]", visible: :all)
      end

      def has_no_palette_preview?
        has_no_css?("link[data-scheme-preview]", visible: :all)
      end

      def layout_dimensions
        rect = find(WIZARD_SELECTOR).evaluate_script(<<~JS)
          (() => {
            const { width, top, bottom } = this.getBoundingClientRect();
            return { width, top, bottom };
          })()
        JS

        {
          panel_width: rect["width"],
          panel_top: rect["top"],
          panel_bottom: rect["bottom"],
          viewport_width: page.evaluate_script("window.innerWidth"),
          viewport_height: page.evaluate_script("window.innerHeight"),
          document_scroll_width: page.evaluate_script("document.documentElement.scrollWidth"),
        }
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

      private

      def user_selectable_switch
        PageObjects::Components::DToggleSwitch.new(
          "#{WIZARD_SELECTOR}__switch-row [aria-labelledby='design-wizard-user-selectable-title']",
        )
      end

      def welcome_banner_switch
        PageObjects::Components::DToggleSwitch.new(
          "#{WIZARD_SELECTOR}__switch-row [aria-labelledby='design-wizard-welcome-banner-title']",
        )
      end
    end
  end
end
