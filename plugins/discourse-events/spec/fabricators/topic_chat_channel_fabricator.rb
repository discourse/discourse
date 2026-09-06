# frozen_string_literal: true

Fabricator(:topic_chat_channel, from: "DiscourseEvents::Livestream::TopicChatChannel") do
  topic
  chat_channel
end
