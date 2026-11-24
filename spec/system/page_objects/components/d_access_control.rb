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
        add_grantee(type: "group", id: group.id, name: group.name)
      end

      def add_user(user)
        add_grantee(type: "user", id: user.id, name: user.username, search: user.username)
      end

      def has_row?(type:, id:)
        component.has_css?(row_selector(type:, id:))
      end

      def has_no_row?(type:, id:)
        component.has_no_css?(row_selector(type:, id:))
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
        dialog.has_content?(message)
      end

      def confirm_loss_warning
        dialog.click_yes
      end

      def cancel_loss_warning
        dialog.click_no
      end

      private

      def component
        form.field(FIELD_NAME).component.find(".d-access-control")
      end

      def add_grantee(type:, id:, name:, search: nil)
        if SiteSetting.enable_new_select_controls
          chooser = PageObjects::Components::UiKit::DSelect.at(new_grantee_chooser_selector)
          chooser.search(search) if search
          chooser.select_value(name)
          return
        end

        chooser = grantee_chooser
        chooser.expand
        chooser.search(search) if search
        chooser.select_row_by_value("#{type}:#{id}")
      end

      def grantee_chooser
        chooser = component.find(".d-access-control__chooser")
        PageObjects::Components::SelectKit.new("##{chooser["id"]}")
      end

      def new_grantee_chooser_selector
        "##{form.field(FIELD_NAME).component["id"]} .d-access-control__chooser.d-select"
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
