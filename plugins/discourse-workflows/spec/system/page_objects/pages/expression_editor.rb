# frozen_string_literal: true

module PageObjects
  module Pages
    module DiscourseWorkflows
      class ExpressionEditor < PageObjects::Pages::Base
        VARIABLE_INPUT_SELECTOR = ".workflows-variable-input"
        CM_EDITOR_SELECTOR = ".cm-editor"
        CM_CONTENT_SELECTOR = ".cm-content"
        AUTOCOMPLETE_SELECTOR = ".cm-tooltip-autocomplete"
        HOVER_TOOLTIP_SELECTOR = ".cm-wf-hover-tooltip"
        MODE_CONTROL_SELECTOR = ".workflows-property-engine__mode-control"
        PREVIEW_SELECTOR = ".expression-preview"

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

        def editor_text
          cm_content.text
        end

        def trigger_autocomplete
          cm_content.send_keys([:control, " "])
          self
        end

        def move_cursor_and_delete(right_count, backspace_count)
          keys = Array.new(right_count, :right) + Array.new(backspace_count, :backspace)
          cm_content.send_keys(*keys)
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

        def hover_variable(name)
          find(".cm-wf-variable", text: name, wait: 5).hover
          self
        end

        def has_no_hover_tooltip?
          page.has_no_css?(HOVER_TOOLTIP_SELECTOR)
        end

        def hover_tooltip_text
          find(HOVER_TOOLTIP_SELECTOR).text
        end

        def has_expression_preview?
          page.has_css?(PREVIEW_SELECTOR, wait: 10)
        end

        def has_expression_preview_result?(state, text:)
          page.has_css?("#{PREVIEW_SELECTOR}__resolved.--#{state}", text: text)
        end

        def has_expression_preview_plaintext?(text)
          page.has_css?("#{PREVIEW_SELECTOR}__plaintext", text: text)
        end

        private

        def cm_content
          find(CM_CONTENT_SELECTOR)
        end
      end
    end
  end
end
