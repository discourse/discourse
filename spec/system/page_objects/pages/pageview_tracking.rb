# frozen_string_literal: true

module PageObjects
  module Pages
    class PageviewTracking < PageObjects::Pages::Base
      def session_id
        browser_root.locator("meta[name='discourse-track-view-session-id']").get_attribute(
          "content",
        )
      end
    end
  end
end
