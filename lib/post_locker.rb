# frozen_string_literal: true

class PostLocker
  def initialize(post, user)
    @post, @user = post, user
  end

  def lock
    Guardian.new(@user).ensure_can_lock_post!(@post)
    was_locked = @post.locked?

    Post.transaction do
      @post.update_column(:locked_by_id, @user.id)
      trigger_after_commit(:post_locked) if !was_locked
      StaffActionLogger.new(@user).log_post_lock(@post, locked: true)
    end
  end

  def unlock
    Guardian.new(@user).ensure_can_lock_post!(@post)
    was_locked = @post.locked?

    Post.transaction do
      @post.update_column(:locked_by_id, nil)
      trigger_after_commit(:post_unlocked) if was_locked
      StaffActionLogger.new(@user).log_post_lock(@post, locked: false)
    end
  end

  private

  # A repeated lock or unlock still records who did it, but isn't a change. The callback is dropped if the
  # transaction (or one enclosing it) rolls back.
  def trigger_after_commit(event)
    DB.after_commit { DiscourseEvent.trigger(event, @post, acting_user: @user) }
  end
end
