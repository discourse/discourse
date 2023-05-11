# frozen_string_literal: true

class PostActionDestroyer
  class DestroyResult < PostActionResult
    attr_accessor :post
  end

  def initialize(destroyed_by, post, post_action_type_id, opts = {})
    @destroyed_by, @post, @post_action_type_id, @opts =
      destroyed_by,
      post,
      post_action_type_id,
      opts
  end

  def self.destroy(destroyed_by, post, action_key, opts = {})
    new(destroyed_by, post, PostActionType.types[action_key], opts).perform
  end

  def perform
    result = DestroyResult.new

    if @post.blank?
      result.not_found = true
      return result
    end

    finder =
      PostAction.where(user: @destroyed_by, post: @post, post_action_type_id: @post_action_type_id)
    finder = finder.with_deleted if @destroyed_by.staff?
    post_action = finder.first

    if post_action.blank?
      result.not_found = true
      return result
    end

    unless @opts[:skip_delete_check] == true || guardian.can_delete?(post_action)
      result.forbidden = true
      result.add_error(I18n.t("invalid_access"))
      return result
    end

    RateLimiter.new(
      @destroyed_by,
      "post_action-#{@post.id}_#{@post_action_type_id}",
      4,
      1.minute,
    ).performed!

    post_action.remove_act!(@destroyed_by)
    post_action.post.unhide! if post_action.staff_took_action
    if @post_action_type_id == PostActionType.types[:like]
      GivenDailyLike.decrement_for(@destroyed_by.id)
    end

    UserActionManager.post_action_destroyed(post_action)
    PostActionNotifier.post_action_deleted(post_action)
    result.success = true
    result.post = @post.reload

    notify_subscribers

    result
  end

  protected

  def self.notify_types
    @notify_types ||= PostActionType.notify_flag_types.keys
  end

  def notify_subscribers
    name = PostActionType.types[@post_action_type_id]
    if name == :like
      @post.publish_change_to_clients!(
        :unliked,
        { likes_count: @post.like_count, user_id: @destroyed_by.id },
      )
    elsif self.class.notify_types.include?(name)
      @post.publish_change_to_clients!(:acted)
    end
  end

  def guardian
    @guardian ||= Guardian.new(@destroyed_by)
  end
end
