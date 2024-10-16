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

      def has_toggle_experiment_button?
        page.has_css?(".admin-new-feature-item__feature-toggle")
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

      def has_version?(version)
        element = find(".admin-new-feature-item__new-feature-version")
        element.has_text?(version)
      end

      def has_date?(date)
        element = find(".admin-config-area-card__title")
        element.has_text?(date)
      end
    end
  end
end
