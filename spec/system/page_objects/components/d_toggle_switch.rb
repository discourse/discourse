# frozen_string_literal: true

module PageObjects
  module Components
    class DToggleSwitch < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def component
        find(@context, visible: :all).native
      end

      def toggle
        actionbuilder = page.driver.browser.action # workaround zero height button
        actionbuilder.click(component).perform
      end
    end
  end
end
