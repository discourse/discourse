# frozen_string_literal: true

module PageObjects
  module Modals
    class GroupDefaultNotifications < PageObjects::Modals::Base
      def click_yes
        footer.locator(".btn-primary").filter(visible: true).click
      end

      def click_no
        footer.locator(".btn:not(.btn-primary)").filter(visible: true).click
      end
    end
  end
end
