# frozen_string_literal: true

module PageObjects
  module Components
    class AceEditor < PageObjects::Components::Base
      def type_input(content)
        editor_input.send_keys(content)
        self
      end

      def fill_input(content)
        editor_input.fill_in(with: content)
        self
      end

      def clear_input
        fill_input("")
      end

      def editor_input
        find(".ace-wrapper .ace_text-input", visible: false)
      end
    end
  end
end
