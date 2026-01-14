# frozen_string_literal: true

module PageObjects
  module Components
    class TopicListHeader < PageObjects::Components::Base
      def has_assign_topics_button?
        page.has_css?(bulk_select_dropdown_item("assign-topics"))
      end

      def click_assign_topics_button
        find(bulk_select_dropdown_item("assign-topics")).click
      end

      def has_unassign_topics_button?
        page.has_css?(bulk_select_dropdown_item("unassign-topics"))
      end

      def click_unassign_topics_button
        find(bulk_select_dropdown_item("unassign-topics")).click
      end
    end
  end
end
