# frozen_string_literal: true

module PageObjects
  module Pages
    class AdminFlagForm < PageObjects::Pages::Base
      def has_disabled_save_button?
        find_button("Save", disabled: true)
      end

      def fill_in_name(name)
        find(".admin-flag-form__name").fill_in(with: name)
      end

      def fill_in_description(description)
        find(".admin-flag-form__description").fill_in(with: description)
      end

      def fill_in_applies_to(applies_to)
        dropdown = PageObjects::Components::SelectKit.new(".admin-flag-form__applies-to")
        dropdown.expand
        dropdown.select_row_by_value(applies_to)
        dropdown.collapse
      end

      def click_save
        find(".admin-flag-form__save").click
      end
    end
  end
end
