# frozen_string_literal: true

module PageObjects
  module Components
    class AceEditor < PageObjects::Components::Base
      def type_input(content)
        editor_input.fill(content)
        self
      end

      def set_input(content)
        # Can't rely on capybara here because ace editor is not a normal input.
        browser_page.evaluate(
          "function(arguments) { return #{"ace.edit(document.getElementsByClassName('ace')[0]).setValue(#{content.to_json})"} }",
          arg: [],
        )
        self
      end

      def clear_input
        set_input("")
      end

      def editor_input
        browser_root
          .locator(".ace-wrapper .ace:not(.hidden)")
          .filter(visible: true)
          .locator(".ace_text-input")
      end

      def has_displayed_content?(content)
        editor = browser_root.locator(".ace-wrapper .ace:not(.hidden)").filter(visible: true)
        lines =
          content
            .split("\n", -1)
            .map { |line| Regexp.new("^#{Regexp.escape(line).gsub("\\ ", "[ \u00a0]")}$") }
        PlaywrightMatchers.have_text(lines, useInnerText: true).matches?(
          editor.locator(".ace_line"),
        )
      end
    end
  end
end
