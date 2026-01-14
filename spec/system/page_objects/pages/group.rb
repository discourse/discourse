# frozen_string_literal: true

module PageObjects
  module Pages
    class Group < PageObjects::Pages::Base
      def visit(group)
        page.visit("/g/#{group.name}")
        self
      end

      def find(selector)
        page.find(".group #{selector}")
      end

      def add_users
        find(".group-members-manage button.group-members-add").click
        self
      end

      def delete_group
        page.find("[data-test-selector='delete-group-button']").click
        page.find(".dialog-footer .btn-danger").click
      end

      def select_user_and_add(user)
        page.find(
          ".modal-container .user-chooser .multi-select-header .select-kit-header-wrapper",
        ).click
        page.find(".modal-container .user-chooser .filter-input").set(user.username)
        page.find(
          ".modal-container li.email-group-user-chooser-row[data-value='#{user.username}']",
        ).click
        page.find(".modal-container button.add.btn-primary").click
        self
      end

      def click_manage
        page.find(".user-primary-navigation .manage").click
      end

      def click_membership
        page.find(".user-secondary-navigation li", text: "Membership").click
      end

      def click_save
        page.find(".group-manage-save").click
      end
    end
  end
end
