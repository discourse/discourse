# frozen_string_literal: true

module PageObjects
  module Pages
    class TopicLivestream < PageObjects::Pages::Base
      LIVESTREAM_URL = "https://example.com/live"

      def cache_livestream_onebox
        Discourse.cache.write(
          Oneboxer.onebox_cache_key(LIVESTREAM_URL),
          { onebox: "<aside>cached livestream</aside>" },
        )
      end

      def create_regular_topic(composer, topic_page)
        visit("/latest")
        topic_page.open_new_topic

        composer.fill_title("Creating a regular topic")
        composer.fill_content("The content for my regular topic")
        composer.create
      end

      def create_livestream_event_topic(composer, topic_page, opts = {})
        visit("/latest")
        topic_page.open_new_topic

        opts = {
          location: LIVESTREAM_URL,
          start: 1.day.from_now.strftime("%Y-%m-%d") + " 13:37",
        }.merge!(opts)

        composer.fill_title("Creating a livestream event topic")

        composer.fill_content <<~MD
          [event start="#{opts[:start]}" status="public" livestream="true" location="#{opts[:location]}"]
          [/event]
        MD
        composer.create
      end

      def create_normal_event_topic(composer, topic_page)
        visit("/latest")
        topic_page.open_new_topic

        composer.fill_title("Creating a normal event topic")
        tomorrow = 1.day.from_now.strftime("%Y-%m-%d")
        composer.fill_content <<~MD
          [event start="#{tomorrow} 13:37" status="public"]
          [/event]
        MD
        composer.create
      end
    end
  end
end
