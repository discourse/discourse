# frozen_string_literal: true

module PageObjects
  module Pages
    class PageviewTracking < PageObjects::Pages::Base
      def session_id
        find("meta[name='discourse-track-view-session-id']", visible: :all)[:content]
      end
    end
  end
end
