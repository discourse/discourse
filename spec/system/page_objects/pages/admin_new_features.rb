# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWhatsNew < PageObjects::Pages::Base
      def visit
        browser_page.goto("/admin/whats-new").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def within_new_feature_group(month_and_year, &block)
        within_browser(
          browser_root.locator(
            ".admin-config-area-card[data-new-features-group='#{month_and_year}']",
          ).filter(visible: true),
        ) { block.call }
      end

      def within_new_feature_item(title, &block)
        within_browser(
          browser_root.locator(".admin-new-feature-item##{title.parameterize.downcase}").filter(
            visible: true,
          ),
        ) { block.call }
      end

      def has_screenshot?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-new-feature-item__screenshot").filter(visible: true),
        )
      end

      def has_no_screenshot?
        have_count(0).matches?(
          browser_root.locator(".admin-new-feature-item__screenshot").filter(visible: true),
        )
      end

      def has_toggle_feature_button?
        have_count(0).does_not_match?(
          browser_root.locator(
            ".admin-new-feature-item__feature-toggle .d-toggle-switch__checkbox",
          ).filter(visible: true),
        )
      end

      def has_learn_more_link?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-new-feature-item__learn-more").filter(visible: true),
        )
      end

      def has_emoji?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-new-feature-item__new-feature-emoji").filter(visible: true),
        )
      end

      def has_no_emoji?
        have_count(0).matches?(
          browser_root.locator(".admin-new-feature-item__new-feature-emoji").filter(visible: true),
        )
      end

      def has_date?(date)
        contain_text(browser_text_pattern(date), useInnerText: true).matches?(
          browser_root.locator(".admin-config-area-card__title").filter(visible: true),
        )
      end

      def has_experimental_text?
        have_count(0).does_not_match?(
          browser_root.locator(".admin-new-feature-item__header-experimental").filter(
            visible: true,
          ),
        )
      end

      def has_no_experimental_text?
        have_count(0).matches?(
          browser_root.locator(".admin-new-feature-item__header-experimental").filter(
            visible: true,
          ),
        )
      end

      def toggle_experiments_only
        PageObjects::Components::DToggleSwitch.new(
          ".admin-new-features__experiments-filter .d-toggle-switch__checkbox",
        ).toggle
      end

      def enable_item_toggle
        PageObjects::Components::DToggleSwitch.new(
          ".admin-new-feature-item__feature-toggle .d-toggle-switch__checkbox",
        )
      end
    end
  end
end
