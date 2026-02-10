# frozen_string_literal: true

module PageObjects
  module Components
    class RichChecklist < PageObjects::Components::Base
      CHECKBOX_SELECTOR = ".chcklst-box"
      UNCHECKED_SELECTOR = "#{CHECKBOX_SELECTOR}.fa.fa-square-o"
      CHECKED_SELECTOR = "#{CHECKBOX_SELECTOR}.checked.fa.fa-square-check-o"

      def initialize(rich_editor)
        @rich_editor = rich_editor
      end

      def click_checkbox(index = 0)
        @rich_editor.find_all(CHECKBOX_SELECTOR)[index].click
        self
      end

      def has_checkboxes?(count:)
        @rich_editor.has_css?(CHECKBOX_SELECTOR, count: count)
      end

      def has_no_checkboxes?
        @rich_editor.has_no_css?(CHECKBOX_SELECTOR)
      end

      def has_checked?(count: 1)
        @rich_editor.has_css?(CHECKED_SELECTOR, count: count)
      end

      def has_unchecked?(count: 1)
        @rich_editor.has_css?(UNCHECKED_SELECTOR, count: count)
      end

      def has_items?(count:)
        @rich_editor.has_css?("ul li", count: count)
      end
    end
  end
end
