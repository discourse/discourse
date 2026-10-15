# frozen_string_literal: true

module PageObjects
  module Components
    class TopicMap < PageObjects::Components::Base
      TOPIC_MAP_KLASS = ".topic-map.--op"

      def is_visible?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(TOPIC_MAP_KLASS).filter(visible: true),
        )
      end

      def is_not_visible?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(TOPIC_MAP_KLASS).filter(visible: true),
        )
      end

      def has_no_users?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{TOPIC_MAP_KLASS} .topic-map__users-trigger").filter(
            visible: true,
          ),
        )
      end

      def has_no_likes?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{TOPIC_MAP_KLASS} .topic-map__likes-trigger").filter(
            visible: true,
          ),
        )
      end

      def has_no_links?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{TOPIC_MAP_KLASS} .topic-map__links-trigger").filter(
            visible: true,
          ),
        )
      end

      def users_count
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__users-trigger .number")
          .filter(visible: true)
          .inner_text
          .strip
          .to_i
      end

      def likes_count
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__likes-trigger .number")
          .filter(visible: true)
          .inner_text
          .strip
          .to_i
      end

      def links_count
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__links-trigger .number")
          .filter(visible: true)
          .inner_text
          .strip
          .to_i
      end

      def views_count
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__views-trigger .number")
          .filter(visible: true)
          .inner_text
          .strip
          .to_i
      end

      def avatars_details
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__users-list")
          .filter(visible: true)
          .locator(".poster.trigger-user-card")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def expanded_avatars_details
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__users-trigger")
          .filter(visible: true)
          .click
        browser_root
          .locator("#{TOPIC_MAP_KLASS} .topic-map__users-content")
          .filter(visible: true)
          .locator(".poster.trigger-user-card")
          .filter(visible: true)
          .tap { |elements| elements.first.wait_for(state: "visible") }
          .all
      end

      def has_no_avatars_details_in_map?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator("#{TOPIC_MAP_KLASS} .topic-map__users-list").filter(visible: true),
        )
      end

      def has_bottom_map?
        PlaywrightMatchers.have_count(0).does_not_match?(
          browser_root.locator(".topic-map.--bottom").filter(visible: true),
        )
      end

      def has_no_bottom_map?
        PlaywrightMatchers.have_count(0).matches?(
          browser_root.locator(".topic-map.--bottom").filter(visible: true),
        )
      end
    end
  end
end
