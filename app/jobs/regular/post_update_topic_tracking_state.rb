# frozen_string_literal: true

module Jobs
  class PostUpdateTopicTrackingState < ::Jobs::Base

    def execute(args)
      post = Post.find_by(id: args[:post_id])

      if post && post.topic
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
