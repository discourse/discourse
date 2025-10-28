# frozen_string_literal: true

module PageObjects
  module Components
    class TopicAdminMenu < Base
      def click_set_topic_timer
        find(".admin-topic-timer-update button").click
        PageObjects::Modals::EditTopicTimer.new
      end
    end
  end
end
