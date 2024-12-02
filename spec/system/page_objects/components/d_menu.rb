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

      def option(selector)
        within("#d-menu-portals") { find(selector) }
      end
    end
  end
end
