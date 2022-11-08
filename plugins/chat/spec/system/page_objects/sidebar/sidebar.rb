# frozen_string_literal: true

module PageObjects
  module Pages
    class Sidebar < PageObjects::Pages::Base
      def start_draft_dm
        find(".sidebar-section-chat-dms .sidebar-section-header-button", visible: false).click
      end
    end
  end
end
