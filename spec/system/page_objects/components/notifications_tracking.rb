# frozen_string_literal: true

module PageObjects
  module Components
    class NotificationsTracking < PageObjects::Components::Base
      attr_reader :context

      def initialize(context)
        @context = context
      end

      def toggle
        trigger.click
        self
      end

      def select_level_id(id)
        content.locator("[data-level-id='#{id}']").filter(visible: true).click
        self
      end

      def select_level_name(name)
        content.locator("[data-level-name='#{name}']").filter(visible: true).click
        self
      end

      def has_selected_level_name?(name)
        have_count(0).does_not_match?(
          browser_root.locator(
            "[data-trigger][data-identifier='#{identifier}'][data-level-name='#{name}']",
          ).filter(visible: true),
        )
      end

      def has_selected_level_id?(id)
        have_count(0).does_not_match?(
          browser_root.locator(
            "[data-trigger][data-identifier='#{identifier}'][data-level-id='#{id}']",
          ).filter(visible: true),
        )
      end

      def trigger
        if @context.is_a?(Playwright::Locator)
          @context
        else
          browser_root.locator(@context).filter(visible: true)
        end
      end

      def content
        browser_root.locator("[data-content][data-identifier='#{identifier}']").filter(
          visible: true,
        )
      end

      def identifier
        trigger["data-identifier"]
      end
    end
  end
end
