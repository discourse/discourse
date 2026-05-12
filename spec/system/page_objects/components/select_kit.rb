# frozen_string_literal: true

module PageObjects
  module Components
    class SelectKit < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        if @context.is_a?(Capybara::Node::Element)
          @context
        else
          find(@context)
        end
      end

      def visible?
        has_css?(@context, visible: true)
      end

      def hidden?
        has_no_css?(@context)
      end

      def expanded_component(skip_collapsed_check: false)
        # Skip collapsed check to avoid infinite loop when called from .expand
        expand if is_collapsed? && !skip_collapsed_check
        locator("#{@context}.is-expanded")
      end

      def collapsed_component
        find(@context + ":not(.is-expanded)")
      end

      def expanded?
        component.has_css?(".select-kit-body", visible: true)
      end

      def is_collapsed?
        has_css?(context) && has_css?("#{context}:not(.is-expanded)", wait: 0)
      end

      def is_not_disabled?
        has_css?(@context + ":not(.disabled)", wait: 0)
      end

      def value
        component.find(".select-kit-header")["data-value"]
      end

      def has_selected_value?(value)
        component.find(".select-kit-header[data-value='#{value}']")
      end

      def has_selected_name?(name)
        component.find(".select-kit-header[data-name='#{name}']")
      end

      def has_no_selection?
        component.has_no_css?(".selected-choice")
      end

      def has_selected_choice_name?(name)
        component.find(".selected-choice[data-name='#{name}']")
      end

      def has_selected_names?(*names)
        selected = component.find(".formatted-selection").text.split(", ")
        names.map(&:to_s).sort == selected.sort
      end

      def has_option_name?(name)
        component.find(".select-kit-collection li[data-name='#{name}']")
      end

      def has_no_option_name?(name)
        component.has_no_css?(".select-kit-collection li[data-name='#{name}']")
      end

      def has_option_value?(value)
        component.find(".select-kit-collection li[data-value='#{value}']")
      end

      def has_no_option_value?(value)
        component.has_no_css?(".select-kit-collection li[data-value='#{value}']")
      end

      def expand
        collapsed_component.find(".select-kit-header", visible: :all).click
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
        has_css?("#{@context}.is-expanded .select-kit-filter .filter-input", visible: true)
      end

      def has_no_filter?
        expanded_component
        has_no_css?("#{@context}.is-expanded .select-kit-filter .filter-input")
      end

      def search(value = nil)
        expanded_component.locator(".select-kit-filter .filter-input").fill(value.to_s)
        wait_for_loaded
      end

      def wait_for_loaded
        has_no_css?("#{@context}.is-loading")
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
        has_css?("#{@context}.is-expanded .select-kit-row.is-selected[data-name='#{name}']")
      end

      def has_no_selected_row?
        expanded_component
        has_no_css?("#{@context}.is-expanded .select-kit-row.is-selected")
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
