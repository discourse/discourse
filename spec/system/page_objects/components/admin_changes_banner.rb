# frozen_string_literal: true

module PageObjects
  module Components
    class AdminChangesBanner < Base
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

      def click_discard
        element.find(".btn-secondary").click
      end

      def has_label?(label)
        element.has_css?(".admin-changes-banner__main-label", text: label)
      end

      private

      def selector
        ".admin-changes-banner"
      end
    end
  end
end
