# frozen_string_literal: true

module PageObjects
  module Pages
    class TopicLivestream < PageObjects::Pages::Base
      def create_livestream_topic(composer, topic_page, tag)
        visit("/latest")
        topic_page.open_new_topic

        composer.fill_title("Creating a livestream topic")
        tag_chooser = PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
        tag_chooser.expand
        tag_chooser.select_row_by_name(tag.name)
        tag_chooser.collapse

        tomorrow = 1.day.from_now.strftime("%Y-%m-%d")
        composer.fill_content <<~MD
          [event start="#{tomorrow} 13:37" status="public" livestream="true" location="https://example.com/live"]
          [/event]
        MD
        composer.create
      end

      def create_regular_topic(composer, topic_page)
        visit("/latest")
        topic_page.open_new_topic

        composer.fill_title("Creating a regular topic")
        composer.fill_content("The content for my regular topic")
        composer.create
      end

      def create_livestream_event_topic(composer, topic_page, tag)
        visit("/latest")
        topic_page.open_new_topic

        composer.fill_title("Creating a livestream event topic")
        tag_chooser = PageObjects::Components::SelectKit.new(".composer-fields .mini-tag-chooser")
        tag_chooser.expand
        tag_chooser.select_row_by_name(tag.name)
        tag_chooser.collapse

        tomorrow = 1.day.from_now.strftime("%Y-%m-%d")
        composer.fill_content <<~MD
          [event start="#{tomorrow} 13:37" status="public" livestream="true" location="https://example.com/live"]
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
