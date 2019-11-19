# frozen_string_literal: true

module Jobs
  class NotifyTagChange < ::Jobs::Base
    def execute(args)
      post = Post.find_by(id: args[:post_id])

      if post&.topic&.visible?
        post_alerter = PostAlerter.new
        post_alerter.notify_post_users(post, User.where(id: args[:notified_user_ids]), include_category_watchers: false)
        post_alerter.notify_first_post_watchers(post, post_alerter.tag_watchers(post.topic))
      end
    end
  end
end
