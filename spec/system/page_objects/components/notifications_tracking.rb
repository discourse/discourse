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
        content.find("[data-level-id='#{id}']").click
        self
      end

      def select_level_name(name)
        content.find("[data-level-name='#{name}']").click
        self
      end

      def has_selected_level_name?(name)
        find("[data-trigger][data-identifier='#{identifier}'][data-level-name='#{name}']")
      end

      def has_selected_level_id?(id)
        find("[data-trigger][data-identifier='#{identifier}'][data-level-id='#{id}']")
      end

      def trigger
        if @context.is_a?(Capybara::Node::Element)
          @context
        else
          find(@context)
        end
      end

      def content
        find("[data-content][data-identifier='#{identifier}']")
      end

      def identifier
        trigger["data-identifier"]
      end
    end
  end
end
