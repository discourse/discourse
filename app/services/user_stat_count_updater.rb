# frozen_string_literal: true

class UserStatCountUpdater
  class << self
    def increment!(post, user_stat: nil, count_type: nil)
      update!(post, user_stat: user_stat, action: :increment!, count_type: count_type)
    end

    def decrement!(post, user_stat: nil, count_type: nil)
      update!(post, user_stat: user_stat, action: :decrement!, count_type: count_type)
    end

    private

    def update!(post, user_stat: nil, action: :increment!, count_type: nil)
      return if !post&.topic
      return if action == :increment! && post.topic.private_message?
      stat = user_stat || post.user&.user_stat

      return if stat.blank?

      # In some cases we don't want to base the column on the
      # post passed in, we may be updating multiple user stats
      # at the same time for a topic
      if count_type.present?
        column = count_type
      else
        column =
          if post.is_first_post?
            :topic_count
          elsif post.post_type == Post.types[:regular]
            :post_count
          end
      end

      return if column.blank?

      # There are lingering bugs in the code base that does not properly increase the count when the status of the post
      # changes. Since we have Job::DirectoryRefreshOlder which runs daily to reconcile the count, there is no need
      # to trigger an error.
      if action == :decrement! && stat.public_send(column) < 1
        if SiteSetting.verbose_user_stat_count_logging
          Rails.logger.warn("Attempted to insert negative count into UserStat##{column} for post with id '#{post.id}'")
        end

        return
      end

      stat.public_send(action, column)
    end
  end
end
