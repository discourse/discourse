# frozen_string_literal: true

module PageObjects
  module Components
    class CodeEditor < PageObjects::Components::Base
      # Takes a selector, or an element already found by the caller.
      def initialize(selector = ".code-editor")
        @selector = selector
      end

      # Written into the document rather than sent as keystrokes, which the
      # editor would auto-indent as it went.
      def type_input(content)
        set_input(value.to_s + content)
      end

      # The editor paints a contenteditable, so the document is set through it
      # rather than filled in as a field.
      def set_input(content)
        page.execute_script(<<~JS, view_element, content)
          const view = arguments[0].codemirrorView;
          view.dispatch({
            changes: { from: 0, to: view.state.doc.length, insert: arguments[1] },
          });
        JS
        self
      end

      def clear_input
        set_input("")
      end

      def value
        page.evaluate_script("arguments[0].codemirrorView.state.doc.toString()", view_element)
      end

      def editor
        @selector.is_a?(String) ? find(@selector) : @selector
      end

      # The wrapper renders before the editor chunk has loaded; the document
      # handle exists only once the editor itself is in the DOM.
      def view_element
        editor.find(".codemirror-editor:has(.cm-editor)")
      end

      def editor_content
        editor.find(".cm-content")
      end

      # Named apart from Capybara's text matchers, which would otherwise take
      # over `have_text` and check the page instead of the document.
      def has_value?(content)
        value == content
      end

      def has_value_including?(content)
        value.include?(content)
      end
    end
  end
end
