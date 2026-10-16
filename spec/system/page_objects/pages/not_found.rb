# frozen_string_literal: true

module PageObjects
  module Pages
    class NotFound < PageObjects::Pages::Base
      def visible?
        have_count(0).does_not_match?(
          browser_root.locator("div.page-not-found").filter(visible: true),
        )
      end
    end
  end
end
