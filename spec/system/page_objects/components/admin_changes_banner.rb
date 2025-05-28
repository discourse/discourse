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

      private

      def selector
        ".admin-changes-banner"
      end
    end
  end
end
