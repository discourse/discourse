# Responsible for logging the actions of admins and moderators.
class StaffActionLogger
  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new('admin is nil') unless @admin and @admin.is_a?(User)
  end

  def log_user_deletion(deleted_user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless deleted_user and deleted_user.is_a?(User)
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:delete_user],
      email: deleted_user.email,
      ip_address: deleted_user.ip_address.to_s,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{deleted_user.send(x)}" }.join(', ')
    }))
  end

  def log_trust_level_change(user, old_trust_level, new_trust_level, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user and user.is_a?(User)
    raise Discourse::InvalidParameters.new('old trust level is invalid') unless TrustLevel.levels.values.include? old_trust_level
    raise Discourse::InvalidParameters.new('new trust level is invalid') unless TrustLevel.levels.values.include? new_trust_level
    UserHistory.create!( params(opts).merge({
      action: UserHistory.actions[:change_trust_level],
      target_user_id: user.id,
      details: "old trust level: #{old_trust_level}, new trust level: #{new_trust_level}"
    }))
  end

  def log_site_setting_change(setting_name, previous_value, new_value, opts={})
    raise Discourse::InvalidParameters.new('setting_name is invalid') unless setting_name.present? and SiteSetting.respond_to?(setting_name)
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:change_site_setting],
      subject: setting_name,
      previous_value: previous_value,
      new_value: new_value
    }))
  end

  SITE_CUSTOMIZATION_LOGGED_ATTRS = ['stylesheet', 'header', 'position', 'enabled', 'key', 'override_default_style']

  def log_site_customization_change(old_record, site_customization_params, opts={})
    raise Discourse::InvalidParameters.new('site_customization_params is nil') unless site_customization_params
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:change_site_customization],
      subject: site_customization_params[:name],
      previous_value: old_record ? old_record.attributes.slice(*SITE_CUSTOMIZATION_LOGGED_ATTRS).to_json : nil,
      new_value: site_customization_params.slice(*(SITE_CUSTOMIZATION_LOGGED_ATTRS.map(&:to_sym))).to_json
    }))
  end

  def log_site_customization_destroy(site_customization, opts={})
    raise Discourse::InvalidParameters.new('site_customization is nil') unless site_customization
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:delete_site_customization],
      subject: site_customization.name,
      previous_value: site_customization.attributes.slice(*SITE_CUSTOMIZATION_LOGGED_ATTRS).to_json
    }))
  end

  def log_user_ban(user, reason, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:ban_user],
      target_user_id: user.id,
      details: reason
    }))
  end

  def log_user_unban(user, opts={})
    raise Discourse::InvalidParameters.new('user is nil') unless user
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:unban_user],
      target_user_id: user.id
    }))
  end

  private

  def params(opts)
    {acting_user_id: @admin.id, context: opts[:context]}
  end

end
