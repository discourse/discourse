# frozen_string_literal: true

require_dependency "post_alerter"

module Jobs
  class NotifyTagChange < Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])

      if post&.topic&.visible?
        post_alerter = PostAlerter.new
        post_alerter.notify_first_post_watchers(post, post_alerter.tag_watchers(post.topic))
      end
    end
  end
end
