# frozen_string_literal: true

module PageObjects
  module Components
    module DiscourseEvents
      class ChatEventOnebox < PageObjects::Components::Base
        SELECTOR = ".chat-message-text .discourse-post-event-onebox"

        def has_event?(event)
          topic = event.post.topic
          title = event.name.presence || topic.title

          has_css?("#{SELECTOR} .event-date") &&
            has_css?("#{SELECTOR} .name a[href='#{event.post.relative_url}']", text: title) &&
            has_css?("#{SELECTOR} .going-button")
        end
      end
    end
  end
end
