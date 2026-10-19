# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminUserFields < PageObjects::Pages::Base
      def visit
        browser_page
          .goto("admin/config/user-fields")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
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
        browser_root.locator(".d-page-header__actions .btn-primary").filter(visible: true).click
      end

      def click_edit
        browser_root.locator(".admin-user_field-item__edit").filter(visible: true).click
      end

      def add_field(name: nil, description: nil, requirement: nil, preferences: [], save: true)
        click_add_field

        form.field("name").fill_in(name)
        form.field("description").fill_in(description)
        form.submit if save
      end

      def has_user_field?(name)
        contain_text(browser_text_pattern(name), useInnerText: true).matches?(browser_content)
      end
    end
  end
end
