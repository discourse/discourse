# frozen_string_literal: true

module Jobs
  class PostUpdateTopicTrackingState < ::Jobs::Base

    def execute(args)
      post = Post.find_by(id: args[:post_id])
      topic = post&.topic
      return unless topic

      if post.topic.private_message?
        TopicTrackingState.publish_private_message(topic, post: post)
        TopicGroup.new_message_update(topic.last_poster, topic.id, post.post_number)
      else
        TopicTrackingState.publish_unmuted(topic)

        if post.post_number > 1
          TopicTrackingState.publish_muted(topic)
          TopicTrackingState.publish_unread(post)
        end

        TopicTrackingState.publish_latest(topic, post.whisper?)
      end
    end

  end
end
