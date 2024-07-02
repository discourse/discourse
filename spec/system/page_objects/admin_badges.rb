# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBadges < PageObjects::Pages::Base
      def visit_page(badge_id = nil)
        path = "/admin/badges"
        path += "/#{badge_id}" if badge_id
        page.visit path
        self
      end

      def new_page
        page.visit "/admin/badges/new"
        self
      end

      def has_badge?(title)
        page.has_css?(".current-badge-header .badge-display-name", text: title)
      end
    end
  end
end
