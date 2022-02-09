# frozen_string_literal: true

class UserStatCountUpdater
  class << self
    def increment!(post, user_stat: nil)
      update!(post, user_stat: user_stat)
    end

    def decrement!(post, user_stat: nil)
      update!(post, user_stat: user_stat, action: :decrement!)
    end

    private

    def update!(post, user_stat: nil, action: :increment!)
      return if !post.topic
      return if post.topic.private_message?
      stat = user_stat || post.user.user_stat

      if post.is_first_post?
        stat.public_send(action, :topic_count)
      elsif post.post_type == Post.types[:regular]
        stat.public_send(action, :post_count)
      end
    rescue ActiveRecord::StatementInvalid => e
      if e.cause.is_a?(PG::CheckViolation)
        # There are still spots in the code base which results in the counter cache going out of sync. However,
        # we have a job that runs on a daily basis which will correct the count. Therefore, avoid raising an error for now
        # and log the exception instead.
        Discourse.warn_exception(
          e,
          message: "Attempted to insert negative count into UserStat#post_count or UserStat#topic_count"
        )
      else
        raise
      end
    end
  end
end
