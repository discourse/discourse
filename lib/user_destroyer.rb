require_dependency 'admin_logger'

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
  def destroy(user)
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise PostsExistError if user.post_count != 0
    User.transaction do
      user.destroy.tap do |u|
        if u
          AdminLogger.new(@admin).log_user_deletion(user)
          DiscourseHub.unregister_nickname(user.username) if SiteSetting.call_discourse_hub?
          MessageBus.publish "/file-change", ["refresh"], user_ids: [user.id]
        end
      end
    end
  end

end