# frozen_string_literal: true

class PostActionDestroyer
  class DestroyResult < PostActionResult
    attr_accessor :post
  end

  def initialize(destroyed_by, post, post_action_type_id)
    @destroyed_by, @post, @post_action_type_id = destroyed_by, post, post_action_type_id
  end

  def self.destroy(destroyed_by, post, action_key)
    new(destroyed_by, post, PostActionType.types[action_key]).perform
  end

  def perform
    result = DestroyResult.new

    if @post.blank?
      result.not_found = true
      return result
    end

    finder = PostAction.where(
      user: @destroyed_by,
      post: @post,
      post_action_type_id: @post_action_type_id
    )
    finder = finder.with_deleted if @destroyed_by.staff?
    post_action = finder.first

    if post_action.blank?
      result.not_found = true
      return result
    end

    unless guardian.can_delete?(post_action)
      result.forbidden = true
      result.add_error(I18n.t("invalid_access"))
      return result
    end

    RateLimiter.new(@destroyed_by, "post_action-#{@post.id}_#{@post_action_type_id}", 4, 1.minute).performed!

    post_action.remove_act!(@destroyed_by)
    post_action.post.unhide! if post_action.staff_took_action
    GivenDailyLike.decrement_for(@destroyed_by.id) if @post_action_type_id == PostActionType.types[:like]

    UserActionManager.post_action_destroyed(post_action)
    PostActionNotifier.post_action_deleted(post_action)

    result.success = true
    result.post = @post.reload

    result
  end

protected

  def guardian
    @guardian ||= Guardian.new(@destroyed_by)
  end
end
