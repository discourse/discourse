# frozen_string_literal: true

module PageObjects
  module Components
    class DMenu < PageObjects::Components::Base
      attr_reader :component

      def initialize(trigger_input, identifier = nil)
        if trigger_input.is_a?(Capybara::Node::Element)
          @component = trigger_input
        else
          @component = find(trigger_input)
        end

        @identifier = identifier
      end

      def expand
        raise "DMenu is already expanded" if is_expanded?
        component.click
      end

      def collapse
        raise "DMenu is already collapsed" if is_collapsed?
        component.click
      end

      def is_expanded?
        component["aria-expanded"] == "true"
      end

      def is_collapsed?
        !is_expanded?
      end

      def portal_with_identifier_selector
        if @identifier.nil?
          "#d-menu-portals"
        else
          "#d-menu-portals [data-identifier=\"#{@identifier}\"]"
        end
      end

      def option(selector, match = nil)
        params = {}
        params[:match] = match if match
        within(portal_with_identifier_selector, visible: false) { find(selector, **params) }
      end

      def has_option?(selector, text = nil)
        params = {}
        params[:text] = text if text
        within(portal_with_identifier_selector) { has_css?(selector, **params) }
      end

      def has_no_option?(selector)
        within(portal_with_identifier_selector) { has_no_css?(selector) }
      end

      def has_value?(value)
        component.has_text?(value)
      end
    end
  end
end
