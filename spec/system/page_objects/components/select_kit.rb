# frozen_string_literal: true

module PageObjects
  module Components
    class SelectKit < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        if @context.is_a?(Playwright::Locator)
          @context
        else
          browser_root.locator(@context).filter(visible: true)
        end
      end

      def visible?
        have_count(0).does_not_match?(component)
      end

      def hidden?
        have_count(0).matches?(component)
      end

      def expanded_component(skip_collapsed_check: false)
        # Skip collapsed check to avoid infinite loop when called from .expand
        expand if is_collapsed? && !skip_collapsed_check
        component
          .and(browser_page.locator(".is-expanded"))
          .tap { |element| element.wait_for(state: "visible") }
      end

      def collapsed_component
        component.and(browser_page.locator(":not(.is-expanded)"))
      end

      def expanded?
        have_count(0).does_not_match?(component.locator(".select-kit-body").filter(visible: true))
      end

      def is_collapsed?
        have_count(0).does_not_match?(component) &&
          component.and(browser_page.locator(":not(.is-expanded)")).count != 0
      end

      def is_not_disabled?
        component.and(browser_page.locator(":not(.disabled)")).count != 0
      end

      def value
        component.locator(".select-kit-header").filter(visible: true).get_attribute("data-value")
      end

      def has_selected_value?(value)
        have_count(0).does_not_match?(
          component.locator(".select-kit-header[data-value='#{value}']").filter(visible: true),
        )
      end

      def has_selected_name?(name)
        have_count(0).does_not_match?(
          component.locator(".select-kit-header[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_no_selection?
        have_count(0).matches?(component.locator(".selected-choice").filter(visible: true))
      end

      def has_selected_choice_name?(name)
        have_count(0).does_not_match?(
          component.locator(".selected-choice[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_selected_names?(*names)
        selected =
          component
            .locator(".formatted-selection")
            .filter(visible: true)
            .inner_text
            .strip
            .split(", ")
        names.map(&:to_s).sort == selected.sort
      end

      def has_option_name?(name)
        have_count(0).does_not_match?(
          component.locator(".select-kit-collection li[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_no_option_name?(name)
        have_count(0).matches?(
          component.locator(".select-kit-collection li[data-name='#{name}']").filter(visible: true),
        )
      end

      def has_option_value?(value)
        have_count(0).does_not_match?(
          component.locator(".select-kit-collection li[data-value='#{value}']").filter(
            visible: true,
          ),
        )
      end

      def has_no_option_value?(value)
        have_count(0).matches?(
          component.locator(".select-kit-collection li[data-value='#{value}']").filter(
            visible: true,
          ),
        )
      end

      def expand
        collapsed_component.locator(".select-kit-header").click
        expanded_component(skip_collapsed_check: true)
      end

      def collapse
        expanded_component.locator(".select-kit-header").click
        collapsed_component
      end

      def collapse_with_escape
        expanded_component.press("Escape")
        collapsed_component
      end

      def has_filter?
        expanded_component # auto-expands if collapsed
        have_count(0).does_not_match?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-filter .filter-input")
            .filter(visible: true),
        )
      end

      def has_no_filter?
        expanded_component
        have_count(0).matches?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-filter .filter-input")
            .filter(visible: true),
        )
      end

      def press_enter_in_filter
        expanded_component.locator(".select-kit-filter .filter-input").press("Enter")
      end

      def search(value = nil)
        expanded_component.locator(".select-kit-filter .filter-input").fill(value.to_s)
        wait_for_loaded
      end

      def wait_for_loaded
        have_count(0).matches?(component.and(browser_page.locator(".is-loading")))
      end

      def select_row_by_value(value)
        expanded_component.locator(".select-kit-row[data-value='#{value}']").click
      end

      def select_row_by_name(name)
        expanded_component.locator(".select-kit-row[data-name='#{name}']").click
      end

      def select_row_by_index(index)
        expanded_component.locator(".select-kit-row[data-index='#{index}']").click
      end

      def unselect_by_name(name)
        expanded_component.locator(".selected-choice[data-name='#{name}']").click
      end

      def clear
        choices = expanded_component.locator(".selected-choice")
        choices.first.click while choices.count > 0
      end

      def has_selected_row_name?(name)
        expanded_component
        have_count(0).does_not_match?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row.is-selected[data-name='#{name}']")
            .filter(visible: true),
        )
      end

      def has_disabled_row_name?(name)
        expanded_component
        have_count(0).does_not_match?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row.disabled[data-name='#{name}']")
            .filter(visible: true),
        )
      end

      def has_no_disabled_row_name?(name)
        expanded_component
        have_count(0).matches?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row.disabled[data-name='#{name}']")
            .filter(visible: true),
        )
      end

      def has_row_synonym_hint?(name, hint_text)
        expanded_component
        contain_text([browser_text_pattern(hint_text)], useInnerText: true).matches?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row[data-name='#{name}'] .synonym-hint")
            .filter(visible: true),
        )
      end

      def has_no_selected_row?
        expanded_component
        have_count(0).matches?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row.is-selected")
            .filter(visible: true),
        )
      end

      def has_disabled_row_reason?(name)
        expanded_component
        have_count(0).does_not_match?(
          component
            .and(browser_page.locator(".is-expanded"))
            .locator(".select-kit-row.disabled[data-name='#{name}'] .disabled-reason")
            .filter(visible: true),
        )
      end

      def option_names
        expanded_component
          .locator(".select-kit-row")
          .all
          .map { |row| row.get_attribute("data-name") }
      end
    end
  end
end
