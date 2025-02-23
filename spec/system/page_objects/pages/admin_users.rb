# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUsers < AdminBase
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
        find(".admin-users-list__search input")
      end

      def user_row(id)
        UserRow.new(find(".directory-table__row[data-user-id=\"#{id}\"]"))
      end

      def users_count
        all(".directory-table__row").size
      end

      def has_correct_breadcrumbs?
        expect(all(".d-breadcrumbs__item").map(&:text)).to eq(
          [I18n.t("js.admin_title"), I18n.t("admin_js.admin.users.title")],
        )
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

      def has_usernames?(usernames)
        expect(all(".directory-table__cell.username").map(&:text)).to eq(usernames)
      end

      def has_none_users?
        has_content?(I18n.t("js.search.no_results"))
      end

      def has_no_emails?
        has_no_css?(".directory-table__column-header--email")
      end

      def has_emails?
        has_css?(".directory-table__column-header--email")
      end

      def click_show_emails
        find(".admin-users__subheader-show-emails").click
      end

      def click_send_invites
        find(".admin-users__header-send-invites").click
      end

      def click_export
        find(".admin-users__header-export-users").click
      end
    end
  end
end
