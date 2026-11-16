# frozen_string_literal: true

module PageObjects
  module Components
    class DFloatingControlBar < Base
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
        element.find(".btn-default").click
      end

      def has_label?(label)
        element.has_css?(".d-floating-control-bar__label", text: label)
      end

      private

      def selector
        ".d-floating-control-bar"
      end
    end

    # Retained so out-of-repo plugins that still reference the admin-era name keep
    # working. Drop it once they have moved to DFloatingControlBar.
    AdminChangesBanner = DFloatingControlBar
  end
end
