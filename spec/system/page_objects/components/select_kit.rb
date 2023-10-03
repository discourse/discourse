# frozen_string_literal: true

module PageObjects
  module Components
    class SelectKit < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        find(@context)
      end

      def visible?
        has_css?(@context)
      end

      def hidden?
        has_no_css?(@context)
      end

      def expanded_component
        expand_if_needed
        find(@context + ".is-expanded")
      end

      def collapsed_component
        find(@context + ":not(.is-expanded)")
      end

      def is_expanded?
        has_css?(context + ".is-expanded")
      end

      def is_collapsed?
        has_css?(context + ":not(.is-expanded)", wait: 0)
      end

      def has_selected_value?(value)
        component.find(".select-kit-header[data-value='#{value}']")
      end

      def has_selected_name?(name)
        component.find(".select-kit-header[data-name='#{name}']")
      end

      def has_selected_choice_name?(name)
        component.find(".selected-choice[data-name='#{name}']")
      end

      def has_option_name?(name)
        component.find(".select-kit-collection li[data-name='#{name}']")
      end

      def expand
        collapsed_component.find(":not(.is-expanded) .select-kit-header", visible: :all).click
        expanded_component
      end

      def collapse
        expanded_component.find(".is-expanded .select-kit-header").click
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

      def expand_if_needed
        expand if is_collapsed?
      end
    end
  end
end
