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
        has_css?(@context)
      end

      def hidden?
        has_no_css?(@context)
      end

      def expanded_component
        return expand if is_collapsed?
        find(@context + ".is-expanded")
      end

      def collapsed_component
        find(@context + ":not(.is-expanded)")
      end

      def is_expanded?
        has_css?(context + ".is-expanded")
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

      def has_option_name?(name)
        component.find(".select-kit-collection li[data-name='#{name}']")
      end

      def has_option_value?(value)
        component.find(".select-kit-collection li[data-value='#{value}']")
      end

      def has_no_option_value?(value)
        component.has_no_css?(".select-kit-collection li[data-value='#{value}']")
      end

      def expand
        collapsed_component.find(".select-kit-header", visible: :all).click
        expanded_component
      end

      def collapse
        expanded_component.find(".select-kit-header").click
        collapsed_component
      end

      def search(value = nil)
        expanded_component.find(".select-kit-filter .filter-input").fill_in(with: value)
      end

      def select_row_by_value(value)
        expanded_component.find(".select-kit-row[data-value='#{value}']").click
      end

      def select_row_by_name(name)
        expanded_component.find(".select-kit-row[data-name='#{name}']").click
      end

      def select_row_by_index(index)
        expanded_component.find(".select-kit-row[data-index='#{index}']").click
      end

      def unselect_by_name(name)
        expanded_component.find(".selected-choice[data-name='#{name}']").click
      end
    end
  end
end
