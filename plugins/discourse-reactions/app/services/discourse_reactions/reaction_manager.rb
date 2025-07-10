# frozen_string_literal: true

module DiscourseReactions
  class ReactionManager
    attr_reader :reaction_value, :previous_reaction_value

    def initialize(reaction_value:, user:, post:)
      @reaction_value = reaction_value
      @user = user
      @post = post
      @like =
        @post.post_actions.find_by(
          user: @user,
          post_action_type_id: PostActionType::LIKE_POST_ACTION_ID,
        )
      @previous_reaction_value =
        if @like && !reaction_user
          DiscourseReactions::Reaction.main_reaction_id
        elsif reaction_user
          old_reaction_value(reaction_user)
        end
    end

    def toggle!
      if (@like && !@user.guardian.can_delete_post_action?(@like)) ||
           (reaction_user && !@user.guardian.can_delete_reaction_user?(reaction_user))
        raise Discourse::InvalidAccess
      end

      ActiveRecord::Base.transaction do
        @reaction = reaction_scope&.first_or_create
        @reaction_user = reaction_user_scope
        if @reaction_value == DiscourseReactions::Reaction.main_reaction_id
          toggle_like
        else
          toggle_reaction
        end
      end
    end

    private

    def toggle_like
      remove_reaction if reaction_user.present?
      @like ? remove_shadow_like : add_shadow_like
    end

    def toggle_reaction
      if reaction_user.present?
        remove_reaction
        return if previous_reaction_value && previous_reaction_value == @reaction_value
      end

      remove_shadow_like if @like
      add_reaction if reaction_user.blank?
    end

    def add_reaction_notification
      DiscourseReactions::ReactionNotification.new(@reaction, @user).create
    end

    def remove_reaction_notification
      DiscourseReactions::ReactionNotification.new(@reaction, @user).delete
    end

    def reaction_scope
      DiscourseReactions::Reaction.where(
        post_id: @post.id,
        reaction_value: @reaction_value,
        reaction_type: DiscourseReactions::Reaction.reaction_types["emoji"],
      )
    end

    def reaction_user_scope
      return nil unless @reaction
      search_reaction_user =
        DiscourseReactions::ReactionUser.where(user_id: @user.id, post_id: @post.id)
      create_reaction_user =
        DiscourseReactions::ReactionUser.new(
          reaction_id: @reaction.id,
          user_id: @user.id,
          post_id: @post.id,
        )
      search_reaction_user.length > 0 ? search_reaction_user.first : create_reaction_user
    end

    def reaction_user
      DiscourseReactions::ReactionUser.find_by(user_id: @user.id, post_id: @post.id)
    end

    def old_reaction_value(reaction_user)
      return unless reaction_user
      DiscourseReactions::Reaction.where(id: reaction_user.reaction_id).first&.reaction_value
    end

    def add_shadow_like(notify: true)
      silent = true
      PostActionCreator.like(@user, @post, silent)
      add_reaction_notification if notify
    end

    def remove_shadow_like
      PostActionDestroyer.new(@user, @post, PostActionType::LIKE_POST_ACTION_ID).perform
      delete_like_reaction
      remove_reaction_notification
    end

    def delete_like_reaction
      DiscourseReactions::Reaction.where(
        reaction_value: DiscourseReactions::Reaction.main_reaction_id,
        post_id: @post.id,
      ).destroy_all
    end

    def add_reaction
      @reaction_user = reaction_user_scope if reaction_user.blank?
      @reaction_user.save!
      add_shadow_like(notify: false) if !reaction_excluded_from_like?
      add_reaction_notification
    end

    def remove_reaction
      @reaction_user.destroy
      remove_shadow_like
      delete_reaction_with_no_users
    end

    def delete_reaction_with_no_users
      DiscourseReactions::Reaction.where(reaction_users_count: 0, post_id: @post.id).destroy_all
    end

    def reaction_excluded_from_like?
      DiscourseReactions::Reaction.reactions_excluded_from_like.include?(@reaction_value)
    end
  end
end
