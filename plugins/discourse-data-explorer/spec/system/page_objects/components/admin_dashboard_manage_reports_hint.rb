# frozen_string_literal: true

module PageObjects
  module Components
    class AdminDashboardManageReportsHint < PageObjects::Components::Base
      SELECTOR = ".manage-reports .de-cta"

      def has_hint?
        has_css?(SELECTOR)
      end

      def has_no_hint?
        has_no_css?(SELECTOR)
      end

      def click_hint
        find(SELECTOR).click
        self
      end
    end
  end
end
