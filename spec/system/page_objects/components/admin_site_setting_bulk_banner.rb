# frozen_string_literal: true

module PageObjects
  module Components
    class AdminSiteSettingBulkBanner < Base
      def visible?
        has_css?(selector)
      end

      def hidden?
        has_no_css?(selector)
      end

      def element
        find(selector)
      end

      def click_save
        element.find(".btn-primary").click
      end

      private

      def selector
        ".admin-site-settings__changes-banner"
      end
    end
  end
end
