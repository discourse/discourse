# frozen_string_literal: true

module PageObjects
  module Components
    class AceEditor < PageObjects::Components::Base
      def type_input(content)
        editor_input.fill_in(with: content)
        self
      end

      def set_input(content)
        # Can't rely on capybara here because ace editor is not a normal input.
        page.evaluate_script(
          "ace.edit(document.getElementsByClassName('ace')[0]).setValue(#{content.to_json})",
        )
        self
      end

      def clear_input
        set_input("")
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
