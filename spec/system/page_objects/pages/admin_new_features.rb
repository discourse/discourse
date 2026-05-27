# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWhatsNew < PageObjects::Pages::Base
      def visit
        page.visit("/admin/whats-new")
        self
      end

      def within_new_feature_group(month_and_year, &block)
        within find(".admin-config-area-card[data-new-features-group='#{month_and_year}']") do
          block.call
        end
      end

      def within_new_feature_item(title, &block)
        within find(
                 ".admin-new-feature-item[data-new-feature-identifier='#{title.parameterize}']",
               ) do
          block.call
        end
      end

      def has_screenshot?
        page.has_css?(".admin-new-feature-item__screenshot")
      end

      def has_no_screenshot?
        page.has_no_css?(".admin-new-feature-item__screenshot")
      end

      def has_toggle_feature_button?
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
        find(".admin-config-area-card__title").has_text?(date)
      end

      def has_experimental_text?
        page.has_css?(".admin-new-feature-item__header-experimental")
      end

      def has_no_experimental_text?
        page.has_no_css?(".admin-new-feature-item__header-experimental")
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
