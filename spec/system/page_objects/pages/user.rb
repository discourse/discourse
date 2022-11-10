# frozen_string_literal: true

module PageObjects
  module Pages
    class User < PageObjects::Pages::Base
      def find(selector)
        page.find(".user-content-wrapper #{selector}")
      end

      def active_user_primary_navigation
        find(".user-primary-navigation li a.active")
      end

      def active_user_secondary_navigation
        find(".user-secondary-navigation li a.active")
      end
    end
  end
end
