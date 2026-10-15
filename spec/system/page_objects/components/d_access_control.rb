# frozen_string_literal: true

module PageObjects
  module Components
    class DAccessControl < PageObjects::Components::Base
      FIELD_NAME = "acl"
      FORM_SELECTOR = ".form-kit"
      ROW_SELECTOR = ".d-access-control__row"

      def form
        @form ||= PageObjects::Components::FormKit.new(FORM_SELECTOR)
      end

      def dialog
        @dialog ||= PageObjects::Components::Dialog.new
      end

      def add_group(group)
        add_grantee(type: "group", id: group.id)
      end

      def add_user(user)
        add_grantee(type: "user", id: user.id, search: user.username)
      end

      def has_row?(type:, id:)
        PlaywrightMatchers.have_count(0).does_not_match?(
          component.locator(row_selector(type:, id:)).filter(visible: true),
        )
      end

      def has_no_row?(type:, id:)
        PlaywrightMatchers.have_count(0).matches?(
          component.locator(row_selector(type:, id:)).filter(visible: true),
        )
      end

      def row(type:, id:)
        DAccessControlRow.new(scoped_row_selector(type:, id:))
      end

      def remove_permission_row(type:, id:)
        row(type:, id:).select_permission("remove")
      end

      def save
        form.submit
      end

      def has_loss_warning?(message)
        dialog.has_displayed_content?(message)
      end

      def confirm_loss_warning
        dialog.click_yes
      end

      def cancel_loss_warning
        dialog.click_no
      end

      private

      def component
        form.field(FIELD_NAME).component.locator(".d-access-control").filter(visible: true)
      end

      def add_grantee(type:, id:, search: nil)
        chooser = grantee_chooser
        chooser.expand
        chooser.search(search) if search
        chooser.select_row_by_value("#{type}:#{id}")
      end

      def grantee_chooser
        chooser = component.locator(".d-access-control__chooser").filter(visible: true)
        PageObjects::Components::SelectKit.new(
          "##{chooser.evaluate("(element, name) => { const value = element[name]; return value !== null && value !== undefined && value !== false && !['object', 'function'].includes(typeof value) ? value : element.getAttribute(name); }", arg: "id")}",
        )
      end

      def row_selector(type:, id:)
        "#{ROW_SELECTOR}[data-row-type='#{type}'][data-row-id='#{id}']"
      end

      def scoped_row_selector(type:, id:)
        field = form.field(FIELD_NAME).component
        "##{field["id"]} #{row_selector(type:, id:)}"
      end
    end
  end
end
