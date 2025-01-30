# frozen_string_literal: true

module PageObjects
  module Components
    class InterfaceColorSelector < PageObjects::Components::Base
      attr_reader :container

      SELECTOR = ".interface-color-selector"

      def initialize(container)
        @container = container
      end

      def available?
        within(container) { has_css?(SELECTOR) }
      end

      def not_available?
        within(container) { has_no_css?(SELECTOR) }
      end

      def expand
        within(container) { find(SELECTOR).click }
      end

      def light_option
        find("#{SELECTOR}__light-option")
      end

      def dark_option
        find("#{SELECTOR}__dark-option")
      end

      def auto_option
        find("#{SELECTOR}__auto-option")
      end
    end
  end
end
