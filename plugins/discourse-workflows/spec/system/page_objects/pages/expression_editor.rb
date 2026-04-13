# frozen_string_literal: true

module PageObjects
  module Pages
    class ExpressionEditor < PageObjects::Pages::Base
      VARIABLE_INPUT_SELECTOR = ".workflows-variable-input"
      CM_EDITOR_SELECTOR = ".cm-editor"
      CM_CONTENT_SELECTOR = ".cm-content"
      AUTOCOMPLETE_SELECTOR = ".cm-tooltip-autocomplete"
      SECTION_HEADER_SELECTOR = ".cm-expr-section-header"
      COMPLETION_INFO_SELECTOR = ".cm-completionInfo"
      HOVER_TOOLTIP_SELECTOR = ".cm-wf-hover-tooltip"
      DROP_CURSOR_SELECTOR = ".cm-dropCursor"
      MODE_CONTROL_SELECTOR = ".workflows-property-engine__mode-control"

      def switch_to_expression_mode
        label =
          find(
            "#{MODE_CONTROL_SELECTOR} input.d-segmented-control__input[value='dynamic']",
            match: :first,
          ).ancestor(".d-segmented-control__label")
        label.click
        self
      end

      def has_expression_editor?
        page.has_css?(CM_EDITOR_SELECTOR)
      end

      def has_no_expression_editor?
        page.has_no_css?(CM_EDITOR_SELECTOR)
      end

      def type_in_editor(text)
        cm_content.click
        cm_content.send_keys(text)
        self
      end

      def clear_and_type(text)
        cm_content.click
        cm_content.send_keys([:control, "a"], :backspace, text)
        self
      end

      def editor_text
        cm_content.text
      end

      def trigger_autocomplete
        cm_content.send_keys([:control, " "])
        self
      end

      def has_autocomplete_dropdown?
        page.has_css?(AUTOCOMPLETE_SELECTOR, wait: 5)
      end

      def has_no_autocomplete_dropdown?
        page.has_no_css?(AUTOCOMPLETE_SELECTOR)
      end

      def autocomplete_options
        all("#{AUTOCOMPLETE_SELECTOR} li[role='option']").map(&:text)
      end

      def has_autocomplete_option?(label)
        page.has_css?("#{AUTOCOMPLETE_SELECTOR} li[role='option']", text: label, wait: 5)
      end

      def has_no_autocomplete_option?(label)
        page.has_no_css?("#{AUTOCOMPLETE_SELECTOR} li[role='option']", text: label)
      end

      def has_section_header?(name)
        page.has_css?(SECTION_HEADER_SELECTOR, text: name)
      end

      def has_no_section_header?(name)
        page.has_no_css?(SECTION_HEADER_SELECTOR, text: name)
      end

      def has_completion_info?
        page.has_css?(COMPLETION_INFO_SELECTOR, wait: 3)
      end

      def has_no_completion_info?
        page.has_no_css?(COMPLETION_INFO_SELECTOR)
      end

      def select_autocomplete_option(label)
        find("#{AUTOCOMPLETE_SELECTOR} li[role='option']", text: label).click
        self
      end

      def has_syntax_error?
        page.has_css?(".cm-wf-error")
      end

      def has_no_syntax_error?
        page.has_no_css?(".cm-wf-error")
      end

      def has_syntax_highlight?(css_class)
        page.has_css?(".cm-editor .#{css_class}")
      end

      def has_no_syntax_highlight?(css_class)
        page.has_no_css?(".cm-editor .#{css_class}")
      end

      def has_hover_tooltip?
        page.has_css?(HOVER_TOOLTIP_SELECTOR, wait: 5)
      end

      def has_no_hover_tooltip?
        page.has_no_css?(HOVER_TOOLTIP_SELECTOR)
      end

      def hover_tooltip_text
        find(HOVER_TOOLTIP_SELECTOR).text
      end

      def has_drop_cursor?
        page.has_css?(DROP_CURSOR_SELECTOR)
      end

      def has_no_drop_cursor?
        page.has_no_css?(DROP_CURSOR_SELECTOR)
      end

      def drag_variable_to_editor(variable_id:, key:, type: "string")
        payload = { id: variable_id, key: key, type: type }.to_json

        page.execute_script(<<~JS, cm_content, payload)
          const [target, payload] = arguments;
          const editor = target.closest('.cm-editor');
          const view = editor.cmView?.view;
          if (!view) return;

          const dataTransfer = new DataTransfer();
          dataTransfer.setData('application/x-workflow-variable', payload);

          const rect = target.getBoundingClientRect();
          const x = rect.left + rect.width / 2;
          const y = rect.top + rect.height / 2;

          target.dispatchEvent(new DragEvent('dragover', {
            bubbles: true, dataTransfer, clientX: x, clientY: y
          }));
          target.dispatchEvent(new DragEvent('drop', {
            bubbles: true, dataTransfer, clientX: x, clientY: y
          }));
        JS
        self
      end

      private

      def cm_content
        find(CM_CONTENT_SELECTOR)
      end
    end
  end
end
