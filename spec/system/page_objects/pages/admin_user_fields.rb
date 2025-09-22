# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserFields < PageObjects::Pages::Base
      def visit
        page.visit "admin/config/user-fields"
        self
      end

      def form
        PageObjects::Components::FormKit.new(".user-field .form-kit")
      end

      def choose_requirement(requirement)
        form = page.find(".user-field")

        form.choose(I18n.t("admin_js.admin.user_fields.requirement.#{requirement}.title"))
      end

      def unselect_preference(preference)
        form = page.find(".user-field")

        form.find(".form-kit__control-checkbox[name='#{preference}']:checked").click
      end

      def click_add_field
        page.find(".d-page-header__actions .btn-primary").click
      end

      def click_edit
        page.find(".admin-user_field-item__edit").click
      end

      def add_field(name: nil, description: nil, requirement: nil, preferences: [])
        click_add_field

        form = page.find(".user-field")

        form.find(".user-field-name").fill_in(with: name)
        form.find(".user-field-desc").fill_in(with: description)
        form.find(".save").click
      end

      def has_user_field?(name)
        page.has_text?(name)
      end
    end
  end
end
