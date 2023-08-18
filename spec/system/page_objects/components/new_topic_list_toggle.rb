# frozen_string_literal: true

module PageObjects
  module Components
    class NewTopicListToggle < PageObjects::Components::Base
      COMMON_SELECTOR = ".topics-replies-toggle"

      ALL_SELECTOR = "#{COMMON_SELECTOR}.all"
      REPLIES_SELECTOR = "#{COMMON_SELECTOR}.replies"
      TOPICS_SELECTOR = "#{COMMON_SELECTOR}.topics"

      def not_rendered?
        has_no_css?(COMMON_SELECTOR)
      end

      def all_tab
        @all_tab ||= PageObjects::Components::NewTopicListToggleTab.new("all", ALL_SELECTOR)
      end

      def replies_tab
        @replies_tab ||=
          PageObjects::Components::NewTopicListToggleTab.new("replies", REPLIES_SELECTOR)
      end

      def topics_tab
        @topics_tab ||=
          PageObjects::Components::NewTopicListToggleTab.new("topics", TOPICS_SELECTOR)
      end
    end
  end
end
