# Responsible for logging the actions of admins and moderators.
class StaffActionLogger
  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new('admin is nil') unless @admin and @admin.is_a?(User)
  end

  def log_user_deletion(deleted_user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless deleted_user and deleted_user.is_a?(User)
    StaffActionLog.create( params(opts).merge({
      action: StaffActionLog.actions[:delete_user],
      target_user_id: deleted_user.id,
      email: deleted_user.email,
      ip_address: deleted_user.ip_address,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{deleted_user.send(x)}" }.join(', ')
    }))
  end

  def log_trust_level_change(user, old_trust_level, new_trust_level, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise Discourse::InvalidParameters.new('old trust level is invalid') unless TrustLevel.levels.values.include? old_trust_level
    raise Discourse::InvalidParameters.new('new trust level is invalid') unless TrustLevel.levels.values.include? new_trust_level
    StaffActionLog.create!( params(opts).merge({
      action: StaffActionLog.actions[:change_trust_level],
      target_user_id: user.id,
      details: "old trust level: #{old_trust_level}, new trust level: #{new_trust_level}"
    }))
  end

  def log_site_setting_change(setting_name, previous_value, new_value, opts={})
    raise Discourse::InvalidParameters.new('setting_name is invalid') unless setting_name.present? and SiteSetting.respond_to?(setting_name)
    StaffActionLog.create( params(opts).merge({
      action: StaffActionLog.actions[:change_site_setting],
      subject: setting_name,
      previous_value: previous_value,
      new_value: new_value
    }))
  end

  private

  def params(opts)
    {staff_user_id: @admin.id, context: opts[:context]}
  end
end
