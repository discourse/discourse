# Responsible for logging the actions of admins and moderators.
class AdminLogger
  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new('admin is nil') unless @admin and @admin.is_a?(User)
  end

  def log_user_deletion(deleted_user)
    raise Discourse::InvalidParameters.new('user is nil') unless deleted_user and deleted_user.is_a?(User)
    AdminLog.create(
      action: AdminLog.actions[:delete_user],
      admin_id: @admin.id,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{deleted_user.send(x)}" }.join(', ')
    )
  end
end