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

      def has_x_results?(count)
        has_selector?(".chat-message-container", count:)
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

      def click_result(message)
        page_locator.locator(
          ".chat-message-search-entry:has(.chat-message-container[data-id=\"#{message.id}\"])",
        ).click
        self
      end

      def scroll_to_bottom
        page.execute_script("window.scrollTo(0, document.body.scrollHeight)")
        wait_for_loading
        self
      end

      def wait_for_loading
        has_selector?(".chat-search-loading .spinner")
        has_no_selector?(".chat-search-loading .spinner")
        self
      end

      private

      def page_locator
        locator(SELECTOR)
      end
    end
  end
end
