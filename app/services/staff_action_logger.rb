require_dependency 'staff_message_format'

# Responsible for logging the actions of admins and moderators.
class StaffActionLogger

  def self.base_attrs
    [:topic_id, :post_id, :context, :subject, :ip_address, :previous_value, :new_value]
  end

  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new(:admin) unless @admin && @admin.is_a?(User)
  end

  USER_FIELDS ||= %i{id username name created_at trust_level last_seen_at last_emailed_at}

  def log_user_deletion(deleted_user, opts = {})
    raise Discourse::InvalidParameters.new(:deleted_user) unless deleted_user && deleted_user.is_a?(User)
    details = USER_FIELDS.map { |x| "#{x}: #{deleted_user.send(x)}" }.join("\n")
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:delete_user],
      ip_address: deleted_user.ip_address.to_s,
      details: details
    ))
  end

  def log_custom(custom_type, details = nil)
    raise Discourse::InvalidParameters.new(:custom_type) unless custom_type

    details ||= {}

    attrs = {}
    StaffActionLogger.base_attrs.each do |attr|
      attrs[attr] = details.delete(attr) if details.has_key?(attr)
    end
    attrs[:details] = details.map { |r| "#{r[0]}: #{r[1]}" }.join("\n")
    attrs[:acting_user_id] = @admin.id
    attrs[:action] = UserHistory.actions[:custom_staff]
    attrs[:custom_type] = custom_type

    UserHistory.create!(attrs)
  end

  def log_post_deletion(deleted_post, opts = {})
    raise Discourse::InvalidParameters.new(:deleted_post) unless deleted_post && deleted_post.is_a?(Post)

    topic = deleted_post.topic || Topic.with_deleted.find_by(id: deleted_post.topic_id)

    username = deleted_post.user.try(:username) || I18n.t('staff_action_logs.unknown')
    name = deleted_post.user.try(:name) || I18n.t('staff_action_logs.unknown')
    topic_title = topic.try(:title) || I18n.t('staff_action_logs.not_found')

    details = [
      "id: #{deleted_post.id}",
      "created_at: #{deleted_post.created_at}",
      "user: #{username} (#{name})",
      "topic: #{topic_title}",
      "post_number: #{deleted_post.post_number}",
      "raw: #{deleted_post.raw}"
    ]

    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:delete_post],
      post_id: deleted_post.id,
      details: details.join("\n")
    ))
  end

  def log_topic_delete_recover(topic, action = "delete_topic", opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)

    user = topic.user ? "#{topic.user.username} (#{topic.user.name})" : "(deleted user)"

    details = [
      "id: #{topic.id}",
      "created_at: #{topic.created_at}",
      "user: #{user}",
      "title: #{topic.title}"
    ]

    if first_post = topic.ordered_posts.with_deleted.first
      details << "raw: #{first_post.raw}"
    end

    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[action.to_sym],
      topic_id: topic.id,
      details: details.join("\n")
    ))
  end

  def log_trust_level_change(user, old_trust_level, new_trust_level, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user && user.is_a?(User)
    raise Discourse::InvalidParameters.new(:old_trust_level) unless TrustLevel.valid? old_trust_level
    raise Discourse::InvalidParameters.new(:new_trust_level) unless TrustLevel.valid? new_trust_level
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_trust_level],
      target_user_id: user.id,
      details: "old trust level: #{old_trust_level}\nnew trust level: #{new_trust_level}"
    ))
  end

  def log_lock_trust_level(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user && user.is_a?(User)
    action = UserHistory.actions[user.manual_locked_trust_level.nil? ? :unlock_trust_level : :lock_trust_level]
    UserHistory.create!(params(opts).merge(
      action: action,
      target_user_id: user.id
    ))
  end

  def log_topic_published(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:topic_published],
      topic_id: topic.id)
    )
  end

  def log_post_lock(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[opts[:locked] ? :post_locked : :post_unlocked],
      post_id: post.id)
    )
  end

  def log_post_edit(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:post_edit],
      post_id: post.id,
      details: "#{opts[:old_raw]}\n\n---\n\n#{post.raw}"
    ))
  end

  def log_site_setting_change(setting_name, previous_value, new_value, opts = {})
    raise Discourse::InvalidParameters.new(:setting_name) unless setting_name.present? && SiteSetting.respond_to?(setting_name)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_site_setting],
      subject: setting_name,
      previous_value: previous_value,
      new_value: new_value
    ))
  end

  def theme_json(theme)
    ThemeSerializer.new(theme, root: false).to_json
  end

  def strip_duplicates(old, cur)
    return [old, cur] unless old && cur

    old = JSON.parse(old)
    cur = JSON.parse(cur)

    old.each do |k, v|
      next if k == "name"
      next if k == "id"
      if (v == cur[k])
        cur.delete(k)
        old.delete(k)
      end
    end

    [old.to_json, cur.to_json]
  end

  def log_theme_change(old_json, new_theme, opts = {})
    raise Discourse::InvalidParameters.new(:new_theme) unless new_theme

    new_json = theme_json(new_theme)

    old_json, new_json = strip_duplicates(old_json, new_json)

    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_theme],
      subject: new_theme.name,
      previous_value: old_json,
      new_value: new_json
    ))
  end

  def log_theme_destroy(theme, opts = {})
    raise Discourse::InvalidParameters.new(:theme) unless theme
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:delete_theme],
      subject: theme.name,
      previous_value: theme_json(theme)
    ))
  end

  def log_site_text_change(subject, new_text = nil, old_text = nil, opts = {})
    raise Discourse::InvalidParameters.new(:subject) unless subject.present?
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_site_text],
      subject: subject,
      previous_value: old_text,
      new_value: new_text
    ))
  end

  def log_username_change(user, old_username, new_username, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_username],
      target_user_id: user.id,
      previous_value: old_username,
      new_value: new_username
    ))
  end

  def log_name_change(user_id, old_name, new_name, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user_id
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:change_name],
      target_user_id: user_id,
      previous_value: old_name,
      new_value: new_name
    ))
  end

  def log_user_suspend(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user

    details = StaffMessageFormat.new(:suspend, reason, opts[:message]).format

    args = params(opts).merge(
      action: UserHistory.actions[:suspend_user],
      target_user_id: user.id,
      details: details
    )
    args[:post_id] = opts[:post_id] if opts[:post_id]
    UserHistory.create!(args)
  end

  def log_user_unsuspend(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:unsuspend_user],
      target_user_id: user.id
    ))
  end

  def log_user_merge(user, source_username, source_email, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:merge_user],
      target_user_id: user.id,
      context: I18n.t("staff_action_logs.user_merged", username: source_username),
      email: source_email
    ))
  end

  BADGE_FIELDS ||= %i{id name description long_description icon image badge_type_id
    badge_grouping_id query allow_title multiple_grant listable target_posts
    enabled auto_revoke show_posts system}

  def log_badge_creation(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge
    details = BADGE_FIELDS.map { |f| [f, badge.send(f)] }.select { |f, v| v.present? }.map { |f, v| "#{f}: #{v}" }
    UserHistory.create!(params.merge(
      action: UserHistory.actions[:create_badge],
      details: details.join("\n")
    ))
  end

  def log_badge_change(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge
    details = ["id: #{badge.id}"]
    badge.previous_changes.each { |f, values| details << "#{f}: #{values[1]}" if BADGE_FIELDS.include?(f.to_sym) }
    UserHistory.create!(params.merge(
      action: UserHistory.actions[:change_badge],
      details: details.join("\n")
    ))
  end

  def log_badge_deletion(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge
    details = BADGE_FIELDS.map { |f| [f, badge.send(f)] }.select { |f, v| v.present? }.map { |f, v| "#{f}: #{v}" }
    UserHistory.create!(params.merge(
      action: UserHistory.actions[:delete_badge],
      details: details.join("\n")
    ))
  end

  def log_badge_grant(user_badge, opts = {})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:grant_badge],
      target_user_id: user_badge.user_id,
      details: user_badge.badge.name
    ))
  end

  def log_badge_revoke(user_badge, opts = {})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:revoke_badge],
      target_user_id: user_badge.user_id,
      details: user_badge.badge.name
    ))
  end

  def log_check_email(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:check_email],
      target_user_id: user.id
    ))
  end

  def log_show_emails(users, opts = {})
    return if users.blank?
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:check_email],
      details: users.map { |u| "[#{u.id}] #{u.username}" }.join("\n")
    ))
  end

  def log_impersonate(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:impersonate],
      target_user_id: user.id
    ))
  end

  def log_roll_up(subnets, opts = {})
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:roll_up],
      details: subnets.join(", ")
    ))
  end

  def log_category_settings_change(category, category_params, old_permissions = nil)
    validate_category(category)

    changed_attributes = category.previous_changes.slice(*category_params.keys)

    if !old_permissions.empty? && (old_permissions != category_params[:permissions])
      changed_attributes.merge!(permissions: [old_permissions.to_json, category_params[:permissions].to_json])
    end

    changed_attributes.each do |key, value|
      UserHistory.create!(params.merge(
        action: UserHistory.actions[:change_category_settings],
        category_id: category.id,
        context: category.url,
        subject: key,
        previous_value: value[0],
        new_value: value[1]
      ))
    end
  end

  def log_category_deletion(category)
    validate_category(category)

    details = [
      "created_at: #{category.created_at}",
      "name: #{category.name}",
      "permissions: #{category.permissions_params}"
    ]

    if parent_category = category.parent_category
      details << "parent_category: #{parent_category.name}"
    end

    UserHistory.create!(params.merge(
      action: UserHistory.actions[:delete_category],
      category_id: category.id,
      details: details.join("\n"),
      context: category.url
    ))
  end

  def log_category_creation(category)
    validate_category(category)

    details = [
      "created_at: #{category.created_at}",
      "name: #{category.name}"
    ]

    UserHistory.create!(params.merge(
      action: UserHistory.actions[:create_category],
      details: details.join("\n"),
      category_id: category.id,
      context: category.url
    ))
  end

  def log_silence_user(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user

    create_args = params(opts).merge(
      action: UserHistory.actions[:silence_user],
      target_user_id: user.id,
      details: opts[:details]
    )
    create_args[:post_id] = opts[:post_id] if opts[:post_id]

    UserHistory.create!(create_args)
  end

  def log_unsilence_user(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:unsilence_user],
      target_user_id: user.id
    ))
  end

  def log_disable_second_factor_auth(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:disabled_second_factor],
      target_user_id: user.id
    ))
  end

  def log_grant_admin(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:grant_admin],
      target_user_id: user.id
    ))
  end

  def log_revoke_admin(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:revoke_admin],
      target_user_id: user.id
    ))
  end

  def log_grant_moderation(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:grant_moderation],
      target_user_id: user.id
    ))
  end

  def log_revoke_moderation(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:revoke_moderation],
      target_user_id: user.id
    ))
  end

  def log_backup_create(opts = {})
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:backup_create],
      ip_address: @admin.ip_address.to_s
    ))
  end

  def log_backup_download(backup, opts = {})
    raise Discourse::InvalidParameters.new(:backup) unless backup
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:backup_download],
      ip_address: @admin.ip_address.to_s,
      details: backup.filename
    ))
  end

  def log_backup_destroy(backup, opts = {})
    raise Discourse::InvalidParameters.new(:backup) unless backup
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:backup_destroy],
      ip_address: @admin.ip_address.to_s,
      details: backup.filename
    ))
  end

  def log_revoke_email(user, reason, opts = {})
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:revoke_email],
      target_user_id: user.id,
      details: reason
    ))
  end

  def log_user_deactivate(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:deactivate_user],
      target_user_id: user.id,
      details: reason
    ))
  end

  def log_user_activate(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:activate_user],
      target_user_id: user.id,
      details: reason
    ))
  end

  def log_wizard_step(step, opts = {})
    raise Discourse::InvalidParameters.new(:step) unless step
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:wizard_step],
      context: step.id
    ))
  end

  def log_change_readonly_mode(state)
    UserHistory.create!(params.merge(
      action: UserHistory.actions[:change_readonly_mode],
      previous_value: !state,
      new_value: state
    ))
  end

  def log_check_personal_message(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:check_personal_message],
      topic_id: topic.id,
      context: topic.relative_url
    ))
  end

  def log_post_approved(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)
    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:post_approved],
      post_id: post.id
    ))
  end

  def log_post_rejected(rejected_post, opts = {})
    raise Discourse::InvalidParameters.new(:rejected_post) unless rejected_post && rejected_post.is_a?(QueuedPost)

    topic = rejected_post.topic || Topic.with_deleted.find_by(id: rejected_post.topic_id)
    topic_title = topic&.title || I18n.t('staff_action_logs.not_found')
    username = rejected_post.user&.username || I18n.t('staff_action_logs.unknown')
    name = rejected_post.user&.name || I18n.t('staff_action_logs.unknown')

    details = [
      "created_at: #{rejected_post.created_at}",
      "rejected_at: #{rejected_post.rejected_at}",
      "user: #{username} (#{name})",
      "topic: #{topic_title}",
      "raw: #{rejected_post.raw}",
    ]

    UserHistory.create!(params(opts).merge(
      action: UserHistory.actions[:post_rejected],
      details: details.join("\n")
    ))
  end

  private

  def params(opts = nil)
    opts ||= {}
    { acting_user_id: @admin.id, context: opts[:context] }
  end

  def validate_category(category)
    raise Discourse::InvalidParameters.new(:category) unless category && category.is_a?(Category)
  end

end
