# frozen_string_literal: true

module DiscourseReactions
  class ReactionNotification
    HEART_ICON_NAME = "heart"

    def initialize(reaction, user)
      @reaction = reaction
      @post = reaction.post
      @user = user
    end

    def create
      post_user = @post.user

      if post_user.user_option&.like_notification_frequency ==
           UserOption.like_notification_frequency_type[:never]
        return
      end

      opts = { user_id: @user.id, display_username: @user.username, display_name: @user.name }

      if @reaction.reaction_value == HEART_ICON_NAME
        opts[:custom_data] = { reaction_icon: @reaction.reaction_value }
      end

      PostAlerter.new.create_notification(post_user, Notification.types[:reaction], @post, opts)
    end

    def delete
      return if DiscourseReactions::Reaction.where(post_id: @post.id).by_user(@user).count != 0
      read = true
      Notification
        .where(
          topic_id: @post.topic_id,
          user_id: @post.user_id,
          post_number: @post.post_number,
          notification_type: Notification.types[:reaction],
        )
        .each do |notification|
          read = false unless notification.read
          notification.destroy
        end
      refresh_notification(read)
    end

    private

    def remaining_reaction_data
      @post
        .reactions
        .joins(:users)
        .order("discourse_reactions_reactions.created_at DESC")
        .where("discourse_reactions_reactions.created_at > ?", 1.day.ago)
        .pluck(:username, :name, :reaction_value)
    end

    def refresh_notification(read)
      return unless @post && @post.user_id && @post.topic

      remaining_data = remaining_reaction_data
      return if remaining_data.blank?

      data = {
        topic_title: @post.topic.title,
        count: remaining_data.length,
        username: remaining_data[0][0],
        display_username: remaining_data[0][0],
        display_name: remaining_data[0][1],
      }

      data[:username2] = remaining_data[1][0] if remaining_data[1]
      data[:name2] = remaining_data[1][1] if remaining_data[1]

      if remaining_data.all? { |element| element[2] == HEART_ICON_NAME }
        data[:reaction_icon] = HEART_ICON_NAME
      end

      Notification.create(
        notification_type: Notification.types[:reaction],
        topic_id: @post.topic_id,
        post_number: @post.post_number,
        user_id: @post.user_id,
        read: read,
        data: data.to_json,
      )
    end
  end
end
