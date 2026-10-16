# frozen_string_literal: true

module PageObjects
  module Modals
    class AdminSearch < PageObjects::Modals::Base
      MODAL_SELECTOR = ".admin-search-modal"

      def search(query)
        browser_root.locator(".admin-search__input-field").filter(visible: true).fill(query)
      end

      def find_result(type, position)
        browser_root
          .locator(".admin-search__result[data-result-type='#{type}']")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all[
          position
        ]
      end

      def input_enter
        browser_root.locator(".admin-search__input-field").filter(visible: true).press("Enter")
      end
    end
  end
end
