# frozen_string_literal: true

module PageObjects
  module Pages
    class ChatSearch < PageObjects::Pages::Base
      SELECTOR = ".c-routes.--search"

      def visit
        page.visit("/chat/search")
        self
      end

      def fill_in(query)
        page_locator.locator(".filter-input").fill(query)

        # Wait for search to complete - either results or no results message
        page_locator.locator(".chat-message-search-entries, .alert.alert-info").wait_for(
          state: "visible",
        )

        self
      end

      def has_results?(*messages)
        messages.each do |message|
          expect(
            page_locator.locator(".chat-message-container[data-id=\"#{message.id}\"]"),
          ).to be_visible
        end
      end

      def has_no_results?
        expect(page_locator.locator(".alert.alert-info")).to be_visible
      end

      private

      def page_locator
        locator(SELECTOR)
      end
    end
  end
end
