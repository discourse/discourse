# frozen_string_literal: true

module Jobs
  class PostUpdateTopicTrackingState < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])
      return if !post&.topic

      topic = post.topic

      if topic.private_message?
        PrivateMessageTopicTrackingState.publish_unread(post) if post.post_number > 1
        if post.post_type != Post.types[:small_action]
          TopicGroup.new_message_update(topic.last_poster, topic.id, post.post_number)
        end
      else
        TopicTrackingState.publish_unmuted(post.topic)
        if post.post_number > 1
          TopicTrackingState.publish_muted(post.topic)
          TopicTrackingState.publish_unread(post)
        end
        TopicTrackingState.publish_latest(post.topic, post.whisper?)
      end
    end
  end
end
