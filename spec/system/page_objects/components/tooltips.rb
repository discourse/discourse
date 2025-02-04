# frozen_string_literal: true

module PageObjects
  module Components
    class Tooltips < PageObjects::Components::Base
      SELECTOR = ".fk-d-tooltip__content"

      attr_reader :identifier

      def initialize(identifier)
        @identifier = identifier
      end

      def find(selector, **kwargs)
        page.find("#{SELECTOR}[data-identifier='#{identifier}'] #{selector}", **kwargs)
      end

      def present?(**kwargs)
        page.has_selector?("#{SELECTOR}[data-identifier='#{identifier}']", **kwargs)
      end

      def not_present?(**kwargs)
        page.has_no_selector?("#{SELECTOR}[data-identifier='#{identifier}']", **kwargs)
      end
    end
  end
end
