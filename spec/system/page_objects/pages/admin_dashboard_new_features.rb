# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboardNewFeatures < PageObjects::Pages::Base
      def visit
        page.visit("/admin/dashboard/whats-new")
        self
      end

      def has_screenshot?
        page.has_css?(".admin-new-feature-item__screenshot")
      end

      def has_no_screenshot?
        page.has_no_css?(".admin-new-feature-item__screenshot")
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
    end
  end
end
