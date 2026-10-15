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
          element.locator(".directory-table__cell-bulk-select").filter(visible: true)
        end

        def has_bulk_select_checkbox?
          PlaywrightMatchers.have_count(0).does_not_match?(
            element.locator(".directory-table__cell-bulk-select").filter(visible: true),
          )
        end

        def has_no_bulk_select_checkbox?
          PlaywrightMatchers.have_count(0).matches?(
            element
              .tap do |parent|
                parent.wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
              end
              .locator(".directory-table__cell-bulk-select")
              .filter(visible: true),
          )
        end

        def username
          element.locator("a[href^='/admin/users']").filter(visible: true)
        end
      end

      def visit
        browser_page
          .goto("/admin/users/list/active")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
      end

      def bulk_select_button
        browser_root.locator(".btn.bulk-select").filter(visible: true)
      end

      def bulk_select_all_button
        browser_root.locator(".btn.bulk-select-all").filter(visible: true)
      end

      def bulk_clear_all_button
        browser_root.locator(".btn.bulk-clear-all").filter(visible: true)
      end

      def search_input
        browser_root.locator(".d-filter-controls__input").filter(visible: true)
      end

      def user_row(id)
        UserRow.new(
          browser_root.locator(".directory-table__row[data-user-id=\"#{id}\"]").filter(
            visible: true,
          ),
        )
      end

      def users_count
        browser_root
          .locator(".directory-table__row")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
          .size
      end

      def has_correct_breadcrumbs?
        expect(
          browser_root
            .locator(".d-breadcrumbs__item")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq([I18n.t("js.admin_title"), I18n.t("admin_js.admin.users.title")])
      end

      def has_users?(user_ids)
        user_ids.all? do |id|
          PlaywrightMatchers.have_count(0).does_not_match?(
            browser_root.locator(".directory-table__row[data-user-id=\"#{id}\"]").filter(
              visible: true,
            ),
          )
        end
      end

      def has_no_users?(user_ids)
        user_ids.all? do |id|
          PlaywrightMatchers.have_count(0).matches?(
            browser_root.locator(".directory-table__row[data-user-id=\"#{id}\"]").filter(
              visible: true,
            ),
          )
        end
      end

      def bulk_actions_dropdown
        PageObjects::Components::DMenu.new(
          browser_root.locator(".bulk-select-admin-users-dropdown-trigger").filter(visible: true),
        )
      end

      def has_bulk_actions_dropdown?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".bulk-select-admin-users-dropdown-trigger").filter(visible: true),
        )
      end

      def has_no_bulk_actions_dropdown?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".bulk-select-admin-users-dropdown-trigger").filter(visible: true),
        )
      end

      def has_usernames?(usernames)
        expect(
          browser_root
            .locator(".directory-table__cell.username")
            .filter(visible: true)
            .tap { |elements| elements.first.wait_for(state: "visible") }
            .all
            .map { |element| element.inner_text.strip },
        ).to eq(usernames)
      end

      def has_none_users?
        PlaywrightMatchers.contain_text(
          browser_text_pattern(I18n.t("js.search.no_results")),
          useInnerText: true,
        ).matches?(browser_content)
      end

      def has_no_emails?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".directory-table__column-header--email").filter(visible: true),
        )
      end

      def has_emails?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".directory-table__column-header--email").filter(visible: true),
        )
      end

      def click_show_emails
        browser_root.locator(".admin-users__subheader-show-emails").filter(visible: true).click
      end

      def click_send_invites
        browser_root.locator(".admin-users__header-send-invites").filter(visible: true).click
      end

      def click_export
        browser_root.locator(".admin-users__header-export-users").filter(visible: true).click
      end
    end
  end
end
