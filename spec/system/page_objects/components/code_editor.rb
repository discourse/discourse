# frozen_string_literal: true

module PageObjects
  module Components
    class CodeEditor < PageObjects::Components::Base
      def initialize(selector = ".code-editor")
        @selector = selector
      end

      def type_input(content)
        editor_content.send_keys(content)
        self
      end

      # The editor paints a contenteditable, so the document is set through it
      # rather than filled in as a field.
      def set_input(content)
        page.execute_script(<<~JS, editor, content)
          const view = arguments[0].querySelector(".codemirror-editor").codemirrorView;
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
        page.evaluate_script(<<~JS, editor)
          arguments[0].querySelector(".codemirror-editor").codemirrorView.state.doc.toString()
        JS
      end

      def editor
        find(@selector)
      end

      def editor_content
        editor.find(".cm-content")
      end

      def has_content?(content)
        value == content
      end
    end
  end
end
