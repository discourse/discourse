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

      column =
        if post.is_first_post?
          :topic_count
        elsif post.post_type == Post.types[:regular]
          :post_count
        end

      return if column.blank?

      if action == :decrement! && stat.public_send(column) < 1
        # There are still spots in the code base which results in the counter cache going out of sync. However,
        # we have a job that runs on a daily basis which will correct the count. Therefore, we always check that we
        # wouldn't end up with a negative count first before inserting.
        Rails.logger.warn("Attempted to insert negative count into UserStat##{column}\n#{caller.join('\n')}")
        return
      end

      stat.public_send(action, column)
    end
  end
end
