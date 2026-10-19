# frozen_string_literal: true

module PageObjects
  module Components
    class TopicAdminMenu < Base
      def click_set_topic_timer
        browser_root.locator(".admin-topic-timer-update button").filter(visible: true).click
        PageObjects::Modals::EditTopicTimer.new
      end
    end
  end
end
