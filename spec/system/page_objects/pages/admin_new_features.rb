# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminNewFeatures < PageObjects::Pages::Base
      def visit
        page.visit("/admin/whats-new")
        self
      end

      def has_screenshot?
        page.has_css?(".admin-new-feature-item__screenshot")
      end

      def has_no_screenshot?
        page.has_no_css?(".admin-new-feature-item__screenshot")
      end

      def has_toggle_feature_button?()
        page.has_css?(".admin-new-feature-item__feature-toggle .d-toggle-switch__checkbox")
      end

      def has_learn_more_link?
        page.has_css?(".admin-new-feature-item__learn-more")
      end

      def has_emoji?
        page.has_css?(".admin-new-feature-item__new-feature-emoji")
      end

      def has_no_emoji?
        page.has_no_css?(".admin-new-feature-item__new-feature-emoji")
      end

      def has_date?(date)
        element = find(".admin-config-area-card__title")
        element.has_text?(date)
      end

      def has_experimental_text?
        page.has_css?(".admin-new-feature-item__header-experimental")
      end

      def has_no_experimental_text?
        page.has_no_css?(".admin-new-feature-item__header-experimental")
      end

      def toggle_experiments_only
        toggle_switch =
          PageObjects::Components::DToggleSwitch.new(
            ".admin-new-features__experiments-filter .d-toggle-switch__checkbox",
          )
        toggle_switch.toggle
      end
    end
  end
end
