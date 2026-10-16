# frozen_string_literal: true

module PageObjects
  module Pages
    class Group < PageObjects::Pages::Base
      def visit(group)
        browser_page.goto("/g/#{group.name}").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        self
      end

      def find(selector)
        browser_root.locator(".group #{selector}").filter(visible: true)
      end

      def add_users
        browser_root
          .locator(".group-members-manage button.group-members-add")
          .filter(visible: true)
          .click
        self
      end

      def invite_members
        browser_root
          .locator(".group-members-manage button.group-members-invite")
          .filter(visible: true)
          .click
        self
      end

      def delete_group
        browser_root
          .locator("[data-test-selector='delete-group-button']")
          .filter(visible: true)
          .click
        browser_root.locator(".dialog-footer .btn-danger").filter(visible: true).click
      end

      def select_user_and_add(user)
        browser_root
          .locator(".modal-container .user-chooser .multi-select-header .select-kit-header-wrapper")
          .filter(visible: true)
          .click
        browser_root
          .locator(".modal-container .user-chooser .filter-input")
          .filter(visible: true)
          .fill(user.username)
        browser_root
          .locator(
            ".modal-container li.email-group-user-chooser-row[data-value='#{user.username}']",
          )
          .filter(visible: true)
          .click
        browser_root.locator(".modal-container button.add.btn-primary").filter(visible: true).click
        self
      end

      def click_manage
        browser_root.locator(".user-primary-navigation .manage").filter(visible: true).click
      end

      def click_membership
        browser_root
          .locator(".user-secondary-navigation li")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern("Membership"))
          .click
      end

      def click_interaction
        browser_root
          .locator(".user-secondary-navigation li")
          .filter(visible: true)
          .filter(hasText: browser_text_pattern(I18n.t("js.groups.manage.interaction.title")))
          .click
      end

      def click_save
        browser_root.locator(".group-manage-save").filter(visible: true).click
      end

      def has_saved?
        contain_text([browser_text_pattern(I18n.t("js.saved"))], useInnerText: true).matches?(
          browser_root.locator(".group-manage-save-button span").filter(visible: true),
        )
      end

      def select_default_notification_level(level)
        select_kit =
          PageObjects::Components::SelectKit.new(".groups-form-default-notification-level")
        select_kit.expand
        select_kit.select_row_by_value(level)
      end
    end
  end
end
