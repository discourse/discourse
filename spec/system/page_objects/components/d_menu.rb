# frozen_string_literal: true

module PageObjects
  module Components
    class DMenu < PageObjects::Components::Base
      attr_reader :component

      def initialize(input)
        if input.is_a?(Capybara::Node::Element)
          @component = input
        else
          @component = find(input)
        end
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

      def option(selector, match = nil)
        params = {}
        params[:match] = match if match
        within("#d-menu-portals") { find(selector, **params) }
      end

      def has_option?(selector, text = nil)
        params = {}
        params[:text] = text if text
        within("#d-menu-portals") { has_css?(selector, **params) }
      end

      def has_no_option?(selector)
        within("#d-menu-portals") { has_no_css?(selector) }
      end

      def has_value?(value)
        component.has_text?(value)
      end
    end
  end
end
