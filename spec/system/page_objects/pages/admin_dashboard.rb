# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminDashboard < PageObjects::Pages::Base
      def visit
        page.visit("/admin")
        self
      end

      def has_admin_notice?(message)
        has_css?(".dashboard-problem", text: message)
      end

      def has_no_admin_notice?(message)
        has_no_css?(".dashboard-problem", text: message)
      end

      def dismiss_notice(message)
        find(".dashboard-problem", text: message).find(".btn").click
      end
    end
  end
end
