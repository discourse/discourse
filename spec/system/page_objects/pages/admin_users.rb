# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUsers < PageObjects::Pages::Base
      class UserRow
        attr_reader :element

        def initialize(element)
          @element = element
        end

        def bulk_select_checkbox
          element.find(".directory-table__cell-bulk-select")
        end

        def has_bulk_select_checkbox?
          element.has_css?(".directory-table__cell-bulk-select")
        end

        def has_no_bulk_select_checkbox?
          element.has_no_css?(".directory-table__cell-bulk-select")
        end
      end

      def visit
        page.visit("/admin/users/list/active")
      end

      def bulk_select_button
        find(".btn.bulk-select")
      end

      def search_input
        find(".admin-users-list__controls .username input")
      end

      def user_row(id)
        UserRow.new(find(".directory-table__row[data-user-id=\"#{id}\"]"))
      end

      def users_count
        all(".directory-table__row").size
      end

      def has_users?(user_ids)
        user_ids.all? { |id| has_css?(".directory-table__row[data-user-id=\"#{id}\"]") }
      end

      def has_no_users?(user_ids)
        user_ids.all? { |id| has_no_css?(".directory-table__row[data-user-id=\"#{id}\"]") }
      end

      def bulk_actions_dropdown
        PageObjects::Components::DMenu.new(find(".bulk-select-admin-users-dropdown-trigger"))
      end

      def has_bulk_actions_dropdown?
        has_css?(".bulk-select-admin-users-dropdown-trigger")
      end

      def has_no_bulk_actions_dropdown?
        has_no_css?(".bulk-select-admin-users-dropdown-trigger")
      end
    end
  end
end
