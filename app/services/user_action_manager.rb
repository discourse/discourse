# frozen_string_literal: true

class UserActionManager
  def self.disable
    @disabled = true
  end

  def self.enable
    @disabled = false
  end

  %i[notification post topic post_action].each { |type| self.class_eval(<<~RUBY) }
      def self.#{type}_created(*args)
        return if @disabled
        #{type}_rows(*args).each { |row| UserAction.log_action!(row) }
      end
      def self.#{type}_destroyed(*args)
        return if @disabled
        #{type}_rows(*args).each { |row| UserAction.remove_action!(row) }
      end
    RUBY

  private

  def self.topic_rows(topic)
    # no action to log here, this can happen if a user is deleted
    # then topic has no user_id
    return [] unless topic.user_id

    row = {
      action_type: topic.private_message? ? UserAction::NEW_PRIVATE_MESSAGE : UserAction::NEW_TOPIC,
      user_id: topic.user_id,
      acting_user_id: topic.user_id,
      target_topic_id: topic.id,
      target_post_id: -1,
      created_at: topic.created_at,
    }

    UserAction.remove_action!(
      row.merge(
        action_type:
          topic.private_message? ? UserAction::NEW_TOPIC : UserAction::NEW_PRIVATE_MESSAGE,
      ),
    )

    rows = [row]

    if topic.private_message?
      topic
        .topic_allowed_users
        .reject { |a| a.user_id == topic.user_id }
        .each do |ta|
          row = row.dup
          row[:user_id] = ta.user_id
          row[:action_type] = UserAction::GOT_PRIVATE_MESSAGE
          rows << row
        end
    end
    rows
  end

  def self.post_rows(post)
    # first post gets nada or if the author has been deleted
    return [] if post.is_first_post? || post.topic.blank? || post.user.blank?

    row = {
      action_type: UserAction::REPLY,
      user_id: post.user_id,
      acting_user_id: post.user_id,
      target_post_id: post.id,
      target_topic_id: post.topic_id,
      created_at: post.created_at,
    }

    rows = [row]

    if post.topic.private_message?
      rows = []
      post.topic.topic_allowed_users.each do |ta|
        row = row.dup
        row[:user_id] = ta.user_id
        row[:action_type] = (
          if ta.user_id == post.user_id
            UserAction::NEW_PRIVATE_MESSAGE
          else
            UserAction::GOT_PRIVATE_MESSAGE
          end
        )
        rows << row
      end
    end

    rows
  end

  def self.notification_rows(post, user, notification_type, acting_user_id)
    action =
      case notification_type
      when Notification.types[:quoted]
        UserAction::QUOTE
      when Notification.types[:replied]
        UserAction::RESPONSE
      when Notification.types[:mentioned]
        UserAction::MENTION
      when Notification.types[:edited]
        UserAction::EDIT
      when Notification.types[:linked]
        UserAction::LINKED
      end

    # skip any invalid items, eg failed to save post and so on
    return [] unless action && post && user && post.id

    [
      {
        action_type: action,
        user_id: user.id,
        acting_user_id: acting_user_id || post.user_id,
        target_topic_id: post.topic_id,
        target_post_id: post.id,
      },
    ]
  end

  def self.post_action_rows(post_action)
    action = UserAction::LIKE if post_action.is_like?
    return [] unless action

    post = Post.with_deleted.where(id: post_action.post_id).first

    row = {
      action_type: action,
      user_id: post_action.user_id,
      acting_user_id: post_action.user_id,
      target_post_id: post_action.post_id,
      target_topic_id: post.topic_id,
      created_at: post_action.created_at,
    }

    if post_action.is_like?
      [row, row.merge(action_type: UserAction::WAS_LIKED, user_id: post.user_id)]
    else
      [row]
    end
  end
end
