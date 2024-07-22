# frozen_string_literal: true

module PageObjects
  module Components
    class TopicMap < PageObjects::Components::Base
      TOPIC_MAP_KLASS = ".topic-map.--op"

      def is_visible?
        has_css?(TOPIC_MAP_KLASS)
      end

      def is_not_visible?
        has_no_css?(TOPIC_MAP_KLASS)
      end

      def has_no_users?
        has_no_css?("#{TOPIC_MAP_KLASS} .topic-map__users-trigger")
      end

      def has_no_likes?
        has_no_css?("#{TOPIC_MAP_KLASS} .topic-map__likes-trigger")
      end

      def has_no_links?
        has_no_css?("#{TOPIC_MAP_KLASS} .topic-map__links-trigger")
      end

      def users_count
        find("#{TOPIC_MAP_KLASS} .topic-map__users-trigger .number").text.to_i
      end

      def likes_count
        find("#{TOPIC_MAP_KLASS} .topic-map__likes-trigger .number").text.to_i
      end

      def links_count
        find("#{TOPIC_MAP_KLASS} .topic-map__links-trigger .number").text.to_i
      end

      def views_count
        find("#{TOPIC_MAP_KLASS} .topic-map__views-trigger .number").text.to_i
      end

      def avatars_details
        find("#{TOPIC_MAP_KLASS} .topic-map__users-list").all(".poster.trigger-user-card")
      end

      def expanded_avatars_details
        find("#{TOPIC_MAP_KLASS} .topic-map__users-trigger").click
        find("#{TOPIC_MAP_KLASS} .topic-map__users-content").all(".poster.trigger-user-card")
      end

      def has_no_avatars_details_in_map?
        has_no_css?("#{TOPIC_MAP_KLASS} .topic-map__users-list")
      end

      def has_bottom_map?
        has_css?(".topic-map.--bottom")
      end

      def has_no_bottom_map?
        has_no_css?(".topic-map.--bottom")
      end
    end
  end
end
