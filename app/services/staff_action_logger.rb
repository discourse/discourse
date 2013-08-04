# Responsible for logging the actions of admins and moderators.
class StaffActionLogger
  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new('admin is nil') unless @admin and @admin.is_a?(User)
  end

  def log_user_deletion(deleted_user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless deleted_user and deleted_user.is_a?(User)
    StaffActionLog.create(
      action: StaffActionLog.actions[:delete_user],
      context: opts[:context], # should be the url from where the staff member deleted the user
      staff_user_id: @admin.id,
      target_user_id: deleted_user.id,
      email: deleted_user.email,
      ip_address: deleted_user.ip_address,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{deleted_user.send(x)}" }.join(', ')
    )
  end

  def log_trust_level_change(user, new_trust_level, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise Discourse::InvalidParameters.new('new trust level is invalid') unless TrustLevel.levels.values.include? new_trust_level
    StaffActionLog.create!(
      action: StaffActionLog.actions[:change_trust_level],
      staff_user_id: @admin.id,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{user.send(x)}" }.join(', ') + "new trust level: #{new_trust_level}"
    )
  end
end
