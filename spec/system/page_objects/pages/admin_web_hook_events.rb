# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminWebHookEvents < PageObjects::Pages::Base
      def visit(id)
        page.visit("/admin/api/web_hooks/#{id}")
        self
      end

      def click_filter_all
        find(".select-kit-header", text: "All Events").click
      end

      def click_filter_delivered
        find(".select-kit-row", text: "Delivered").click
      end

      def click_filter_failed
        find(".select-kit-row", text: "Failed").click
      end

      def has_web_hook_event?(id)
        page.has_css?("li .event-id", text: id)
      end

      def has_no_web_hook_event?(id)
        page.has_no_css?("li .event-id", text: id)
      end
    end
  end
end
