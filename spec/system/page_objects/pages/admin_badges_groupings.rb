# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminBadgesGroupings < PageObjects::Pages::Base
      def add_grouping(name)
        within_browser(modal) do
          browser_root.locator(".badge-groupings__add-grouping").filter(visible: true).click
          browser_root.locator(".badge-grouping-name-input").filter(visible: true).fill(name)
        end

        save

        self
      end

      def save
        browser_root.locator(".badge-groupings__save").filter(visible: true).click
        expect(self).to be_closed
        self
      end

      def modal
        browser_root.locator(".badge-groupings-modal").filter(visible: true)
      end

      def closed?
        have_count(0).matches?(browser_root.locator(".badge-groupings-modal").filter(visible: true))
      end
    end
  end
end
