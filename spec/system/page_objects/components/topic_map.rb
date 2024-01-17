# frozen_string_literal: true

module PageObjects
  module Components
    class TopicMap < PageObjects::Components::Base
      TOPIC_MAP_KLASS = ".topic-map"

      def is_visible?
        has_css?(TOPIC_MAP_KLASS)
      end

      def is_not_visible?
        has_no_css?(TOPIC_MAP_KLASS)
      end

      def is_collapsed?
        has_css?("#{TOPIC_MAP_KLASS} .map-collapsed")
      end

      def expand
        find("#{TOPIC_MAP_KLASS} .map-collapsed .btn").click if is_collapsed?
      end

      def has_no_likes?
        has_no_css?("#{TOPIC_MAP_KLASS} .likes")
      end

      def has_no_links?
        has_no_css?("#{TOPIC_MAP_KLASS} .links")
      end

      def users_count
        find("#{TOPIC_MAP_KLASS} .users .number").text.to_i
      end

      def replies_count
        find("#{TOPIC_MAP_KLASS} .replies .number").text.to_i
      end

      def likes_count
        find("#{TOPIC_MAP_KLASS} .likes .number").text.to_i
      end

      def links_count
        find("#{TOPIC_MAP_KLASS} .links .number").text.to_i
      end

      def views_count
        find("#{TOPIC_MAP_KLASS} .views .number").text.to_i
      end

      def created_details
        find("#{TOPIC_MAP_KLASS} .topic-map-post.created-at")
      end

      def created_relative_date
        created_details.find(".relative-date").text
      end

      def last_reply_details
        find("#{TOPIC_MAP_KLASS} .topic-map-post.last-reply")
      end

      def last_reply_relative_date
        last_reply_details.find(".relative-date").text
      end

      def avatars_details
        find("#{TOPIC_MAP_KLASS} .map .avatars").all(".poster.trigger-user-card")
      end

      def expanded_map_avatars_details
        find("#{TOPIC_MAP_KLASS} .topic-map-expanded .avatars").all(".poster.trigger-user-card")
      end

      def has_no_avatars_details_in_map?
        has_no_css?("#{TOPIC_MAP_KLASS} .map .avatars")
      end
    end
  end
end
