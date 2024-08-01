# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlagForm < PageObjects::Pages::Base
      def fill_in_name(name)
        form.field("name").fill_in(name)
      end

      def fill_in_description(description)
        form.field("description").fill_in(description)
      end

      def fill_in_applies_to(applies_to)
        dropdown = PageObjects::Components::SelectKit.new(".admin-flag-form__applies-to")
        dropdown.expand
        dropdown.select_row_by_value(applies_to)
        dropdown.collapse
      end

      def click_save
        form.submit
      end

      def form
        PageObjects::Components::FormKit.new(".admin-flag-form .form-kit")
      end
    end
  end
end
