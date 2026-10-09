# frozen_string_literal: true

class PostLocker
  def initialize(post, user)
    @post, @user = post, user
  end

  def lock
    Guardian.new(@user).ensure_can_lock_post!(@post)

    Post.transaction do
      previous_locked_by_id = @post.locked_by_id
      @post.update_column(:locked_by_id, @user.id)
      StaffActionLogger.new(@user).log_post_lock(
        @post,
        locked: true,
        previous_value: previous_locked_by_id,
      )
    end
  end

  def unlock
    Guardian.new(@user).ensure_can_lock_post!(@post)

    Post.transaction do
      previous_locked_by_id = @post.locked_by_id
      @post.update_column(:locked_by_id, nil)
      StaffActionLogger.new(@user).log_post_lock(
        @post,
        locked: false,
        previous_value: previous_locked_by_id,
      )
    end
  end
end
