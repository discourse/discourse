# Responsible for logging the actions of admins and moderators.
class StaffActionLogger

  def self.base_attrs
    [:topic_id, :post_id, :context, :subject, :ip_address, :previous_value, :new_value]
  end

  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new(:admin) unless @admin && @admin.is_a?(User)
  end

  def log_user_deletion(deleted_user, opts={})
    raise Discourse::InvalidParameters.new(:deleted_user) unless deleted_user && deleted_user.is_a?(User)
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:delete_user],
      email: deleted_user.email,
      ip_address: deleted_user.ip_address.to_s,
      details: [:id, :username, :name, :created_at, :trust_level, :last_seen_at, :last_emailed_at].map { |x| "#{x}: #{deleted_user.send(x)}" }.join("\n")
    }))
  end

  def log_custom(custom_type, details=nil)
    raise Discourse::InvalidParameters.new(:custom_type) unless custom_type

    details ||= {}

    attrs = {}
    StaffActionLogger.base_attrs.each do |attr|
      attrs[attr] = details.delete(attr) if details.has_key?(attr)
    end
    attrs[:details] = details.map {|r| "#{r[0]}: #{r[1]}"}.join("\n")
    attrs[:acting_user_id] = @admin.id
    attrs[:action] = UserHistory.actions[:custom_staff]
    attrs[:custom_type] = custom_type

    UserHistory.create(attrs)
  end

  def log_post_deletion(deleted_post, opts={})
    raise Discourse::InvalidParameters.new(:deleted_post) unless deleted_post && deleted_post.is_a?(Post)

    topic = deleted_post.topic || Topic.with_deleted.find(deleted_post.topic_id)

    username = deleted_post.user.try(:username) || "unknown"
    name = deleted_post.user.try(:name) || "unknown"

    details = [
      "id: #{deleted_post.id}",
      "created_at: #{deleted_post.created_at}",
      "user: #{username} (#{name})",
      "topic: #{topic.title}",
      "post_number: #{deleted_post.post_number}",
      "raw: #{deleted_post.raw}"
    ]

    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:delete_post],
      post_id: deleted_post.id,
      details: details.join("\n")
    }))
  end

  def log_topic_deletion(deleted_topic, opts={})
    raise Discourse::InvalidParameters.new(:deleted_topic) unless deleted_topic && deleted_topic.is_a?(Topic)

    details = [
      "id: #{deleted_topic.id}",
      "created_at: #{deleted_topic.created_at}",
      "user: #{deleted_topic.user.username} (#{deleted_topic.user.name})",
      "title: #{deleted_topic.title}"
    ]

    if first_post = deleted_topic.ordered_posts.first
      details << "raw: #{first_post.raw}"
    end

    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:delete_topic],
      topic_id: deleted_topic.id,
      details: details.join("\n")
    }))
  end

  def log_trust_level_change(user, old_trust_level, new_trust_level, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user && user.is_a?(User)
    raise Discourse::InvalidParameters.new(:old_trust_level) unless TrustLevel.valid? old_trust_level
    raise Discourse::InvalidParameters.new(:new_trust_level) unless TrustLevel.valid? new_trust_level
    UserHistory.create!( params(opts).merge({
      action: UserHistory.actions[:change_trust_level],
      target_user_id: user.id,
      details: "old trust level: #{old_trust_level}\nnew trust level: #{new_trust_level}"
    }))
  end

  def log_site_setting_change(setting_name, previous_value, new_value, opts={})
    raise Discourse::InvalidParameters.new(:setting_name) unless setting_name.present? && SiteSetting.respond_to?(setting_name)
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:change_site_setting],
      subject: setting_name,
      previous_value: previous_value,
      new_value: new_value
    }))
  end

  SITE_CUSTOMIZATION_LOGGED_ATTRS = [
    'stylesheet', 'mobile_stylesheet',
    'header', 'mobile_header',
    'top', 'mobile_top',
    'footer', 'mobile_footer',
    'head_tag',
    'body_tag',
    'position',
    'enabled',
    'key'
  ]

  def log_site_customization_change(old_record, site_customization_params, opts={})
    raise Discourse::InvalidParameters.new(:site_customization_params) unless site_customization_params
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:change_site_customization],
      subject: site_customization_params[:name],
      previous_value: old_record ? old_record.attributes.slice(*SITE_CUSTOMIZATION_LOGGED_ATTRS).to_json : nil,
      new_value: site_customization_params.slice(*(SITE_CUSTOMIZATION_LOGGED_ATTRS.map(&:to_sym))).to_json
    }))
  end

  def log_site_customization_destroy(site_customization, opts={})
    raise Discourse::InvalidParameters.new(:site_customization) unless site_customization
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:delete_site_customization],
      subject: site_customization.name,
      previous_value: site_customization.attributes.slice(*SITE_CUSTOMIZATION_LOGGED_ATTRS).to_json
    }))
  end

  def log_username_change(user, old_username, new_username, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:change_username],
      target_user_id: user.id,
      previous_value: old_username,
      new_value: new_username
    }))
  end

  def log_user_suspend(user, reason, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:suspend_user],
      target_user_id: user.id,
      details: reason
    }))
  end

  def log_user_unsuspend(user, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:unsuspend_user],
      target_user_id: user.id
    }))
  end

  def log_badge_grant(user_badge, opts={})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:grant_badge],
      target_user_id: user_badge.user_id,
      details: user_badge.badge.name
    }))
  end

  def log_badge_revoke(user_badge, opts={})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create( params(opts).merge({
      action: UserHistory.actions[:revoke_badge],
      target_user_id: user_badge.user_id,
      details: user_badge.badge.name
    }))
  end

  def log_check_email(user, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:check_email],
      target_user_id: user.id
    }))
  end

  def log_show_emails(users, opts={})
    return if users.blank?
    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:check_email],
      details: users.map { |u| "[#{u.id}] #{u.username}"}.join("\n")
    }))
  end

  def log_impersonate(user, opts={})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:impersonate],
      target_user_id: user.id
    }))
  end

  def log_roll_up(subnets, opts={})
    UserHistory.create(params(opts).merge({
      action: UserHistory.actions[:roll_up],
      details: subnets.join(", ")
    }))
  end

  private

    def params(opts=nil)
      opts ||= {}
      { acting_user_id: @admin.id, context: opts[:context] }
    end

end
