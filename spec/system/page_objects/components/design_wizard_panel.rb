# frozen_string_literal: true

module PageObjects
  module Components
    class DesignWizardPanel < PageObjects::Components::Base
      WIZARD_SELECTOR = ".design-wizard"

      def visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(WIZARD_SELECTOR).filter(visible: true),
        )
      end

      def hidden?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(WIZARD_SELECTOR).filter(visible: true),
        )
      end

      def has_site_sidebar?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".sidebar-sections").filter(visible: true),
        )
      end

      def select_theme(theme_id)
        browser_root
          .locator("#{WIZARD_SELECTOR}__theme-card[data-theme-id='#{theme_id}']")
          .filter(visible: true)
          .click
      end

      def has_selected_theme?(theme)
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(
            "#{WIZARD_SELECTOR}__theme-card[data-theme-id='#{theme.id}'] input[type='radio']:checked",
          ).filter(visible: true),
        )
      end

      def has_no_selected_theme?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{WIZARD_SELECTOR}__theme-card input[type='radio']:checked").filter(
            visible: true,
          ),
        )
      end

      def has_disabled_next?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("#{WIZARD_SELECTOR}__next[disabled]").filter(visible: true),
        )
      end

      def select_palette(pair_key)
        browser_root
          .locator("#{WIZARD_SELECTOR}__swatch[data-pair-key='#{pair_key}']")
          .filter(visible: true)
          .click
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
        browser_root
          .locator("#{WIZARD_SELECTOR}__homepage-card[data-homepage='#{key}']")
          .filter(visible: true)
          .click
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
        browser_root
          .locator("#{WIZARD_SELECTOR}__option-row[data-welcome-banner-location='#{key}']")
          .filter(visible: true)
          .click
      end

      def select_search_experience(key)
        browser_root
          .locator("#{WIZARD_SELECTOR}__option-row[data-search-experience='#{key}']")
          .filter(visible: true)
          .click
      end

      def select_body_font(font_key)
        groups =
          browser_root
            .locator("#{WIZARD_SELECTOR}__font-group")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
        groups[0].locator("#{WIZARD_SELECTOR}__font-select").filter(visible: true).click
        browser_root
          .locator(
            "[data-identifier='design-wizard-base-font'] .btn.body-font-#{font_key.tr("_", "-")}",
          )
          .filter(visible: true)
          .click
      end

      def has_palette_preview?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator("link[data-scheme-id]"),
        )
      end

      def has_no_palette_preview?
        PlaywrightMatchers.have_count(0).matches?(browser_root.locator("link[data-scheme-id]"))
      end

      def layout_dimensions
        rect =
          browser_root
            .locator(WIZARD_SELECTOR)
            .filter(visible: true)
            .evaluate(
              "(element, args) => (function() { return #{<<~JS} }).apply(element, args)",
          (() => {
            const { width, top, bottom } = this.getBoundingClientRect();
            return { width, top, bottom };
          })()
        JS
              arg: [],
            )

        {
          panel_width: rect["width"],
          panel_top: rect["top"],
          panel_bottom: rect["bottom"],
          viewport_width:
            browser_page.evaluate("function(arguments) { return window.innerWidth }", arg: []),
          viewport_height:
            browser_page.evaluate("function(arguments) { return window.innerHeight }", arg: []),
          document_scroll_width:
            browser_page.evaluate(
              "function(arguments) { return document.documentElement.scrollWidth }",
              arg: [],
            ),
        }
      end

      def next_step
        browser_root.locator("#{WIZARD_SELECTOR}__next").filter(visible: true).click
      end

      def save
        browser_root.locator("#{WIZARD_SELECTOR}__save").filter(visible: true).click
      end

      def close
        browser_root.locator("#{WIZARD_SELECTOR}__close").filter(visible: true).click
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
