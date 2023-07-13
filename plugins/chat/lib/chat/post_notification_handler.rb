# frozen_string_literal: true

##
# Handles :post_alerter_after_save_post events from
# core. Used for notifying users that their chat message
# has been quoted in a post.
module Chat
  class PostNotificationHandler
    attr_reader :post

    def initialize(post, notified_users)
      @post = post
      @notified_users = notified_users
    end

    def handle
      return false if post.post_type == Post.types[:whisper]
      return false if post.topic.blank?
      return false if post.topic.private_message?

      quoted_users = extract_quoted_users(post)
      if @notified_users.present?
        quoted_users = quoted_users.where("users.id NOT IN (?)", @notified_users)
      end

      opts = { user_id: post.user.id, display_username: post.user.username }
      quoted_users.each do |user|
        # PostAlerter.create_notification handles many edge cases, such as
        # muting, ignoring, double notifications etc.
        PostAlerter.new.create_notification(user, Notification.types[:chat_quoted], post, opts)
      end
    end

    private

    def extract_quoted_users(post)
      usernames =
        post.raw.scan(/\[chat quote=\"([^;]+);.+\"\]/).uniq.map { |q| q.first.strip.downcase }
      User.where.not(id: post.user_id).where(username_lower: usernames)
    end
  end
end
