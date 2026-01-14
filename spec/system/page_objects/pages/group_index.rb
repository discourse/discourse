# frozen_string_literal: true

module PageObjects
  module Pages
    class GroupIndex < PageObjects::Pages::Base
      def visit
        page.visit("/groups")
        self
      end

      def click_new_group
        page.find(".groups-header-new").click
        self
      end
    end
  end
end
