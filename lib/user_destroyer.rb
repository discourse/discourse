# Responsible for destroying a User record
class UserDestroyer

  class PostsExistError < RuntimeError; end

  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new('admin is nil') unless @admin and @admin.is_a?(User)
    raise Discourse::InvalidAccess unless @admin.admin?
  end

  # Returns false if the user failed to be deleted.
  # Returns a frozen instance of the User if the delete succeeded.
  def destroy(user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise PostsExistError if !opts[:delete_posts] && user.post_count != 0
    User.transaction do
      if opts[:delete_posts]
        user.posts.each do |post|
          PostDestroyer.new(@admin, post).destroy
        end
        raise PostsExistError if user.reload.post_count != 0
      end
      user.destroy.tap do |u|
        if u
          if opts[:block_email]
            b = BlockedEmail.block(u.email)
            b.record_match! if b
          end
          Post.with_deleted.where(user_id: user.id).update_all("nuked_user = true")
          StaffActionLogger.new(@admin).log_user_deletion(user)
          DiscourseHub.unregister_nickname(user.username) if SiteSetting.call_discourse_hub?
          MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
        end
      end
    end
  end

end