# frozen_string_literal: true

module PageObjects
  module Pages
    class UserPreferencesChat < PageObjects::Pages::Base
      def visit
        page.visit("/my/preferences/chat")
        self
      end

      def emoji_picker_triggers
        all(".emoji-picker-trigger", visible: true)
      end

      def reaction_buttons
        all(".emoji-pickers button")
      end

      def reactions_selected
        reaction_buttons.map { |b| b.find("img")[:title] }
      end

      def select_option_value(selector, value)
        select_kit = PageObjects::Components::SelectKit.new(selector)
        select_kit.expand
        select_kit.select_row_by_value(value)
      end

      def selected_option_value(selector)
        PageObjects::Components::SelectKit.new(selector).value
      end

      def save_changes_and_refresh
        button_element = page.find(".save-changes")
        button_element.click

        wait_until_hidden(button_element)
      end
    end
  end
end
