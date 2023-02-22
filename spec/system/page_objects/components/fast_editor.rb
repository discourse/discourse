# frozen_string_literal: true

module PageObjects
  module Components
    class FastEditor < PageObjects::Components::Base
      def fill_content(content)
        fast_edit_input.fill_in(with: content)
        self
      end

      def clear_content
        fill_content("")
      end

      def has_content?(content)
        fast_edit_input.value == content
      end

      def save
        find(".save-fast-edit").click
      end

      def fast_edit_input
        find("#fast-edit-input")
      end
    end
  end
end
