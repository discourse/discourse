# frozen_string_literal: true

class PostLocker
  def initialize(post, user)
    @post, @user = post, user
  end

  def lock
    Guardian.new(@user).ensure_can_lock_post!(@post)

    Post.transaction do
      @post.update_column(:locked_by_id, @user.id)
      StaffActionLogger.new(@user).log_post_lock(@post, locked: true)
    end
  end

  def unlock
    Guardian.new(@user).ensure_can_lock_post!(@post)

    Post.transaction do
      @post.update_column(:locked_by_id, nil)
      StaffActionLogger.new(@user).log_post_lock(@post, locked: false)
    end
  end
end
