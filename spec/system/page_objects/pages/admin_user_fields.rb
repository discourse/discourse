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
        form.choose_conditional(requirement)
      end

      def unselect_preference(preference)
        form.field(preference).uncheck
      end

      def click_add_field
        page.find(".d-page-header__actions .btn-primary").click
      end

      def click_edit
        page.find(".admin-user_field-item__edit").click
      end

      def add_field(name: nil, description: nil, requirement: nil, preferences: [], save: true)
        click_add_field

        form.field("name").fill_in(name)
        form.field("description").fill_in(description)
        form.submit if save
      end

      def has_user_field?(name)
        page.has_text?(name)
      end
    end
  end
end
