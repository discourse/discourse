# frozen_string_literal: true

module PageObjects
  module Components
    class UserMenu < PageObjects::Components::Base
      def click_assignments_tab
        click_link("user-menu-button-assign-list")
        has_css?("#quick-access-assign-list")
        self
      end

      def has_assignments_in_order?(assignments)
        expect(all(".notification.assigned .item-description").map(&:text)).to eq(assignments)
      end
    end
  end
end
