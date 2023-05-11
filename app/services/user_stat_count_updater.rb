# frozen_string_literal: true

class UserStatCountUpdater
  class << self
    def increment!(post, user_stat: nil)
      update_using_operator!(post, user_stat: user_stat, action: :increment!)
    end

    def decrement!(post, user_stat: nil)
      update_using_operator!(post, user_stat: user_stat, action: :decrement!)
    end

    def set!(user_stat:, count:, count_column:)
      return if user_stat.blank?
      return if !%i[post_count topic_count].include?(count_column)

      if SiteSetting.verbose_user_stat_count_logging && count < 0
        Rails.logger.warn(
          "Attempted to insert negative count into UserStat##{count_column} for user #{user_stat.user_id}, using 0 instead. Caller:\n #{caller[0..10].join("\n")}",
        )
      end

      user_stat.update_column(count_column, [count, 0].max)
    end

    private

    def update_using_operator!(post, user_stat: nil, action: :increment!)
      return if !post&.topic
      return if action == :increment! && post.topic.private_message?
      stat = user_stat || post.user&.user_stat

      return if stat.blank?

      column =
        if post.is_first_post?
          :topic_count
        elsif post.post_type == Post.types[:regular]
          :post_count
        end

      return if column.blank?

      # There are lingering bugs in the code base that does not properly increase the count when the status of the post
      # changes. Since we have Job::DirectoryRefreshOlder which runs daily to reconcile the count, there is no need
      # to trigger an error.
      if action == :decrement! && stat.public_send(column) < 1
        if SiteSetting.verbose_user_stat_count_logging
          Rails.logger.warn(
            "Attempted to insert negative count into UserStat##{column} for post with id '#{post.id}'. Caller:\n #{caller[0..10].join("\n")}",
          )
        end

        return
      end

      stat.public_send(action, column)
    end
  end
end
