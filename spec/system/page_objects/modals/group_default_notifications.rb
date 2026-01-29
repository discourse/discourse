# frozen_string_literal: true

module PageObjects
  module Modals
    class GroupDefaultNotifications < PageObjects::Modals::Base
      def click_yes
        footer.find(".btn-primary").click
      end

      def click_no
        footer.find(".btn:not(.btn-primary)").click
      end
    end
  end
end
