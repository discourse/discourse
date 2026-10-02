# frozen_string_literal: true
module PageObjects
  module Native
    class Composer
      def initialize(page)
        @page = page
      end

      def visit
        @page.goto("/new-topic")
      end

      def opened_composer
        @page.locator("#reply-control.open:visible")
      end

      def rich_editor
        @page.locator(".d-editor-input.ProseMirror:visible")
      end

      def editor
        @page.locator("#reply-control .d-editor-input:visible")
      end

      def markdown_editor
        @page.locator("#reply-control textarea.d-editor-input:visible")
      end

      def type_content(content)
        editor.press_sequentially(content, timeout: 30_000)
      end

      def select_all
        editor.press(RUBY_PLATFORM.match?(/darwin/i) ? "Meta+a" : "Control+a", timeout: 30_000)
      end

      def select_code_block
        code_block.evaluate(<<~JS)
          element => {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(element);
            selection.removeAllRanges();
            selection.addRange(range);
          }
        JS
      end

      def select_paragraph_text(start_index:, end_index: nil)
        paragraphs.evaluate(<<~JS, arg: [start_index, end_index])
          (element, [start, end]) => {
            const selection = window.getSelection();
            const range = document.createRange();
            const textNode = element.firstChild;
            range.setStart(textNode, start);
            range.setEnd(textNode, end ?? textNode.textContent.length);
            selection.removeAllRanges();
            selection.addRange(range);
          }
        JS
      end

      def select_inline_code
        inline_code.evaluate(<<~JS)
          element => {
            const selection = window.getSelection();
            const range = document.createRange();
            range.selectNodeContents(element);
            selection.removeAllRanges();
            selection.addRange(range);
          }
        JS
      end

      def toggle_rich_editor
        toggle = @page.locator("#reply-control .composer-toggle-switch")
        rich = toggle.get_attribute("data-rich-editor")
        toggle.click
        @page.locator(
          (
            if rich
              "#reply-control .d-editor-container.--markdown-editor-enabled"
            else
              "#reply-control .d-editor-container.--rich-editor-enabled"
            end
          ),
        ).wait_for(state: "visible", timeout: Capybara.default_max_wait_time * 1000)
      end

      def code_button
        @page.locator(".toolbar__button.code")
      end

      def active_code_button
        @page.locator(".toolbar__button.code.--active:visible")
      end

      def code_block
        rich_editor.locator("pre code:visible")
      end

      def inline_code
        rich_editor.locator("code:visible")
      end

      def paragraphs
        rich_editor.locator("p:visible")
      end

      def paragraph_containing(text)
        paragraphs.filter(hasText: text).first
      end
    end
  end
end
