# frozen_string_literal: true

module PageObjects
  module Components
    class AceEditor < PageObjects::Components::Base
      def type_input(content)
        editor_input.send_keys(content)
        self
      end

      def fill_input(content)
        # Clear the input before filling it in because capybara's fill_in method doesn't seem to replace existing content
        # unless the content is a blank string.
        editor_input.fill_in(with: "")
        editor_input.fill_in(with: content)
        self
      end

      def clear_input
        fill_input("")
      end

      def editor_input
        find(".ace-wrapper .ace:not(.hidden)", visible: true).find(
          ".ace_text-input",
          visible: false,
        )
      end

      def has_content?(content)
        editor_content = all(".ace_line").map(&:text).join("\n")
        editor_content == content
      end
    end
  end
end
