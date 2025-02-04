# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlagForm < PageObjects::Pages::Base
      def fill_in_name(name)
        form.field("name").fill_in(name)
        self
      end

      def fill_in_description(description)
        form.field("description").fill_in(description)
        self
      end

      def select_applies_to(applies_to)
        dropdown = PageObjects::Components::SelectKit.new(".admin-flag-form__applies-to")
        dropdown.expand
        dropdown.select_row_by_value(applies_to)
        dropdown.collapse
        self
      end

      def click_save
        form.submit
        expect(page).to have_no_css(
          ".admin-config.flags.new",
          wait: Capybara.default_max_wait_time * 3,
        )
        expect(page).to have_css(".admin-flag-item__name", wait: Capybara.default_max_wait_time * 3)
      end

      def form
        @form ||= PageObjects::Components::FormKit.new(".admin-flag-form .form-kit")
      end
    end
  end
end
