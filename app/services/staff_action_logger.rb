# frozen_string_literal: true

# Responsible for logging the actions of admins and moderators.
class StaffActionLogger
  def self.base_attrs
    %i[topic_id post_id context subject ip_address previous_value new_value]
  end

  def initialize(admin)
    @admin = admin
    raise Discourse::InvalidParameters.new(:admin) unless @admin && @admin.is_a?(User)
  end

  USER_FIELDS = %i[id username name created_at trust_level last_seen_at last_emailed_at]

  def log_user_deletion(deleted_user, opts = {})
    unless deleted_user && deleted_user.is_a?(User)
      raise Discourse::InvalidParameters.new(:deleted_user)
    end

    details = USER_FIELDS.map { |x| "#{x}: #{deleted_user.public_send(x)}" }.join("\n")

    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:delete_user],
        ip_address: deleted_user.ip_address.to_s,
        details: details,
      ),
    )
  end

  def log_custom(custom_type, details = nil)
    raise Discourse::InvalidParameters.new(:custom_type) unless custom_type

    details ||= {}

    attrs = {}
    StaffActionLogger.base_attrs.each do |attr|
      attrs[attr] = details.delete(attr) if details.has_key?(attr)
    end
    attrs[:details] = details.map { |r| "#{r[0]}: #{truncate(r[1].to_s)}" }.join("\n")
    attrs[:acting_user_id] = @admin.id
    attrs[:action] = UserHistory.actions[:custom_staff]
    attrs[:custom_type] = custom_type

    UserHistory.create!(attrs)
  end

  def edit_directory_columns_details(column_data, directory_column)
    directory_column = directory_column.attributes.transform_values(&:to_s)
    previous_value = directory_column
    new_value = directory_column.clone

    directory_column.each do |key, value|
      if column_data[key] != value && column_data[key].present?
        new_value[key] = column_data[key]
      elsif key != "name"
        previous_value.delete key
        new_value.delete key
      end
    end

    [previous_value.to_json, new_value.to_json]
  end

  def log_post_deletion(deleted_post, opts = {})
    unless deleted_post && deleted_post.is_a?(Post)
      raise Discourse::InvalidParameters.new(:deleted_post)
    end

    topic = deleted_post.topic || Topic.with_deleted.find_by(id: deleted_post.topic_id)

    username = deleted_post.user.try(:username) || I18n.t("staff_action_logs.unknown")
    name = deleted_post.user.try(:name) || I18n.t("staff_action_logs.unknown")
    topic_title = topic.try(:title) || I18n.t("staff_action_logs.not_found")

    if opts[:permanent]
      details = []
    else
      details = [
        "id: #{deleted_post.id}",
        "created_at: #{deleted_post.created_at}",
        "user: #{username} (#{name})",
        "topic: #{topic_title}",
        "post_number: #{deleted_post.post_number}",
        "raw: #{truncate(deleted_post.raw)}",
      ]
    end

    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[opts[:permanent] ? :delete_post_permanently : :delete_post],
        post_id: deleted_post.id,
        details: details.join("\n"),
      ),
    )
  end

  def log_topic_delete_recover(topic, action = "delete_topic", opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)

    user = topic.user ? "#{topic.user.username} (#{topic.user.name})" : "(deleted user)"

    if action == "delete_topic_permanently"
      details = []
    else
      details = [
        "id: #{topic.id}",
        "created_at: #{topic.created_at}",
        "user: #{user}",
        "title: #{topic.title}",
      ]

      if first_post = topic.ordered_posts.with_deleted.first
        details << "raw: #{truncate(first_post.raw)}"
      end
    end

    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[action.to_sym],
        topic_id: topic.id,
        details: details.join("\n"),
      ),
    )
  end

  def log_trust_level_change(user, old_trust_level, new_trust_level, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user && user.is_a?(User)
    unless TrustLevel.valid? old_trust_level
      raise Discourse::InvalidParameters.new(:old_trust_level)
    end
    unless TrustLevel.valid? new_trust_level
      raise Discourse::InvalidParameters.new(:new_trust_level)
    end
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_trust_level],
        target_user_id: user.id,
        previous_value: old_trust_level,
        new_value: new_trust_level,
      ),
    )
  end

  def log_lock_trust_level(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user && user.is_a?(User)
    action =
      UserHistory.actions[
        user.manual_locked_trust_level.nil? ? :unlock_trust_level : :lock_trust_level
      ]
    UserHistory.create!(params(opts).merge(action: action, target_user_id: user.id))
  end

  def log_topic_published(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:topic_published], topic_id: topic.id),
    )
  end

  def log_topic_timestamps_changed(topic, new_timestamp, previous_timestamp, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:topic_timestamps_changed],
        topic_id: topic.id,
        new_value: new_timestamp,
        previous_value: previous_timestamp,
      ),
    )
  end

  def log_post_lock(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[opts[:locked] ? :post_locked : :post_unlocked],
        post_id: post.id,
      ),
    )
  end

  def log_post_edit(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:post_edit],
        post_id: post.id,
        details: "#{truncate(opts[:old_raw])}\n\n---\n\n#{truncate(post.raw)}",
      ),
    )
  end

  def log_topic_closed(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[opts[:closed] ? :topic_closed : :topic_opened],
        topic_id: topic.id,
      ),
    )
  end

  def log_topic_archived(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[opts[:archived] ? :topic_archived : :topic_unarchived],
        topic_id: topic.id,
      ),
    )
  end

  def log_topic_slow_mode(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)

    details = opts[:enabled] ? ["interval: #{opts[:seconds]}", "until: #{opts[:until]}"] : []

    UserHistory.create!(
      params(opts).merge(
        action:
          UserHistory.actions[opts[:enabled] ? :topic_slow_mode_set : :topic_slow_mode_removed],
        topic_id: topic.id,
        details: details.join("\n"),
      ),
    )
  end

  def log_post_staff_note(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post && post.is_a?(Post)

    args =
      params(opts).merge(
        action:
          UserHistory.actions[
            opts[:new_value].present? ? :post_staff_note_create : :post_staff_note_destroy
          ],
        post_id: post.id,
      )
    args[:new_value] = opts[:new_value] if opts[:new_value].present?
    args[:previous_value] = opts[:old_value] if opts[:old_value].present?

    UserHistory.create!(params(opts).merge(args))
  end

  def log_site_setting_change(setting_name, previous_value, new_value, opts = {})
    unless setting_name.present? && SiteSetting.respond_to?(setting_name)
      raise Discourse::InvalidParameters.new(:setting_name)
    end
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_site_setting],
        subject: setting_name,
        previous_value: previous_value&.to_s,
        new_value: new_value&.to_s,
      ),
    )
  end

  def theme_json(theme)
    ThemeSerializer.new(theme, root: false, include_theme_field_values: true).to_json
  end

  def strip_duplicates(old, cur)
    return old, cur unless old && cur

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

    UserHistory.create!(
      params(opts).merge(json_params(old_json, new_json)).merge(
        action: UserHistory.actions[:change_theme],
        subject: new_theme.name,
      ),
    )
  end

  def log_theme_destroy(theme, opts = {})
    raise Discourse::InvalidParameters.new(:theme) unless theme
    UserHistory.create!(
      params(opts).merge(json_params(theme_json(theme), nil)).merge(
        action: UserHistory.actions[:delete_theme],
        subject: theme.name,
      ),
    )
  end

  def log_theme_component_disabled(component)
    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:disable_theme_component],
        subject: component.name,
        context: component.id,
      ),
    )
  end

  def log_theme_component_enabled(component)
    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:enable_theme_component],
        subject: component.name,
        context: component.id,
      ),
    )
  end

  def log_theme_setting_change(setting_name, previous_value, new_value, theme, opts = {})
    raise Discourse::InvalidParameters.new(:theme) unless theme
    unless theme.cached_settings.has_key?(setting_name)
      raise Discourse::InvalidParameters.new(:setting_name)
    end

    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_theme_setting],
        subject: "#{theme.name}: #{setting_name}",
        previous_value: previous_value,
        new_value: new_value,
      ),
    )
  end

  def log_site_text_change(subject, new_text = nil, old_text = nil, opts = {})
    raise Discourse::InvalidParameters.new(:subject) if subject.blank?
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_site_text],
        subject: subject,
        previous_value: old_text,
        new_value: new_text,
      ),
    )
  end

  def log_username_change(user, old_username, new_username, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_username],
        target_user_id: user.id,
        previous_value: old_username,
        new_value: new_username,
      ),
    )
  end

  def log_name_change(user_id, old_name, new_name, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user_id
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_name],
        target_user_id: user_id,
        previous_value: old_name,
        new_value: new_name,
      ),
    )
  end

  def log_user_suspend(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user

    details = StaffMessageFormat.new(:suspend, reason, opts[:message]).format

    args =
      params(opts).merge(
        action: UserHistory.actions[:suspend_user],
        target_user_id: user.id,
        details: details,
      )
    args[:post_id] = opts[:post_id] if opts[:post_id]
    UserHistory.create!(args)
  end

  def log_user_unsuspend(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:unsuspend_user], target_user_id: user.id),
    )
  end

  def log_user_merge(user, source_username, source_email, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:merge_user],
        target_user_id: user.id,
        context: I18n.t("staff_action_logs.user_merged", username: source_username),
        email: source_email,
      ),
    )
  end

  BADGE_FIELDS = %i[
    id
    name
    description
    long_description
    icon
    image_upload_id
    badge_type_id
    badge_grouping_id
    query
    allow_title
    multiple_grant
    listable
    target_posts
    enabled
    auto_revoke
    show_posts
    system
  ]

  def log_badge_creation(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge

    details =
      BADGE_FIELDS
        .map { |f| [f, badge.public_send(f)] }
        .select { |f, v| v.present? }
        .map { |f, v| "#{f}: #{v}" }

    UserHistory.create!(
      params.merge(action: UserHistory.actions[:create_badge], details: details.join("\n")),
    )
  end

  def log_badge_change(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge
    details = ["id: #{badge.id}"]
    badge.previous_changes.each do |f, values|
      details << "#{f}: #{values[1]}" if BADGE_FIELDS.include?(f.to_sym)
    end
    UserHistory.create!(
      params.merge(action: UserHistory.actions[:change_badge], details: details.join("\n")),
    )
  end

  def log_badge_deletion(badge)
    raise Discourse::InvalidParameters.new(:badge) unless badge

    details =
      BADGE_FIELDS
        .map { |f| [f, badge.public_send(f)] }
        .select { |f, v| v.present? }
        .map { |f, v| "#{f}: #{v}" }

    UserHistory.create!(
      params.merge(action: UserHistory.actions[:delete_badge], details: details.join("\n")),
    )
  end

  def log_badge_grant(user_badge, opts = {})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:grant_badge],
        target_user_id: user_badge.user_id,
        details: user_badge.badge.name,
      ),
    )
  end

  def log_badge_revoke(user_badge, opts = {})
    raise Discourse::InvalidParameters.new(:user_badge) unless user_badge
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:revoke_badge],
        target_user_id: user_badge.user_id,
        details: user_badge.badge.name,
      ),
    )
  end

  def log_title_revoke(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:revoke_title],
        target_user_id: user.id,
        details: opts[:revoke_reason],
        previous_value: opts[:previous_value],
      ),
    )
  end

  def log_title_change(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:change_title],
        target_user_id: user.id,
        details: opts[:details],
        new_value: opts[:new_value],
        previous_value: opts[:previous_value],
      ),
    )
  end

  def log_change_upload_secure_status(opts = {})
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:override_upload_secure_status],
        details: [
          "upload_id: #{opts[:upload_id]}",
          "reason: #{I18n.t("uploads.marked_insecure_from_theme_component_reason")}",
        ].join("\n"),
        new_value: opts[:new_value],
      ),
    )
  end

  def log_check_email(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:check_email], target_user_id: user.id),
    )
  end

  def log_show_emails(users, opts = {})
    return if users.blank?
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:check_email],
        details: users.map { |u| "[#{u.id}] #{u.username}" }.join("\n"),
      ),
    )
  end

  def log_impersonate(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:impersonate], target_user_id: user.id),
    )
  end

  def log_roll_up(subnet, ips, opts = {})
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:roll_up],
        details: "#{subnet} from #{ips.join(", ")}",
      ),
    )
  end

  def log_category_settings_change(
    category,
    category_params,
    old_permissions: nil,
    old_custom_fields: nil
  )
    validate_category(category)

    changed_attributes = category.previous_changes.slice(*category_params.keys)

    if !old_permissions.empty? && (old_permissions != category_params[:permissions].to_h)
      changed_attributes.merge!(
        permissions: [old_permissions.to_json, category_params[:permissions].to_json],
      )
    end

    if old_custom_fields && category_params[:custom_fields]
      category_params[:custom_fields].each do |key, value|
        next if old_custom_fields[key] == value
        changed_attributes["custom_fields[#{key}]"] = [old_custom_fields[key], value]
      end
    end

    changed_attributes.each do |key, value|
      UserHistory.create!(
        params.merge(
          action: UserHistory.actions[:change_category_settings],
          category_id: category.id,
          context: category.url,
          subject: key,
          previous_value: value[0],
          new_value: value[1],
        ),
      )
    end
  end

  def log_category_deletion(category)
    validate_category(category)

    details = [
      "created_at: #{category.created_at}",
      "name: #{category.name}",
      "permissions: #{category.permissions_params}",
    ]

    if parent_category = category.parent_category
      details << "parent_category: #{parent_category.name}"
    end

    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:delete_category],
        category_id: category.id,
        details: details.join("\n"),
        context: category.url,
      ),
    )
  end

  def log_category_creation(category)
    validate_category(category)

    details = ["created_at: #{category.created_at}", "name: #{category.name}"]

    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:create_category],
        details: details.join("\n"),
        category_id: category.id,
        context: category.url,
      ),
    )
  end

  def log_silence_user(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user

    create_args =
      params(opts).merge(
        action: UserHistory.actions[:silence_user],
        target_user_id: user.id,
        details: opts[:details],
      )
    create_args[:post_id] = opts[:post_id] if opts[:post_id]

    UserHistory.create!(create_args)
  end

  def log_unsilence_user(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:unsilence_user], target_user_id: user.id),
    )
  end

  def log_disable_second_factor_auth(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:disabled_second_factor],
        target_user_id: user.id,
      ),
    )
  end

  def log_grant_admin(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:grant_admin], target_user_id: user.id),
    )
  end

  def log_revoke_admin(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:revoke_admin], target_user_id: user.id),
    )
  end

  def log_grant_moderation(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:grant_moderation], target_user_id: user.id),
    )
  end

  def log_revoke_moderation(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:revoke_moderation], target_user_id: user.id),
    )
  end

  def log_backup_create(opts = {})
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:backup_create],
        ip_address: @admin.ip_address.to_s,
      ),
    )
  end

  def log_entity_export(entity, opts = {})
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:entity_export],
        ip_address: @admin.ip_address.to_s,
        subject: entity,
      ),
    )
  end

  def log_backup_download(backup, opts = {})
    raise Discourse::InvalidParameters.new(:backup) unless backup
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:backup_download],
        ip_address: @admin.ip_address.to_s,
        details: backup.filename,
      ),
    )
  end

  def log_backup_destroy(backup, opts = {})
    raise Discourse::InvalidParameters.new(:backup) unless backup
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:backup_destroy],
        ip_address: @admin.ip_address.to_s,
        details: backup.filename,
      ),
    )
  end

  def log_revoke_email(user, reason, opts = {})
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:revoke_email],
        target_user_id: user.id,
        details: reason,
      ),
    )
  end

  def log_user_approve(user, opts = {})
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:approve_user], target_user_id: user.id),
    )
  end

  def log_user_deactivate(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:deactivate_user],
        target_user_id: user.id,
        details: reason,
      ),
    )
  end

  def log_user_activate(user, reason, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:activate_user],
        target_user_id: user.id,
        details: reason,
      ),
    )
  end

  def log_wizard_step(step, opts = {})
    raise Discourse::InvalidParameters.new(:step) unless step
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:wizard_step], context: step.id),
    )
  end

  def log_change_readonly_mode(state)
    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:change_readonly_mode],
        previous_value: !state,
        new_value: state,
      ),
    )
  end

  def log_check_personal_message(topic, opts = {})
    raise Discourse::InvalidParameters.new(:topic) unless topic && topic.is_a?(Topic)
    UserHistory.create!(
      params(opts).merge(
        action: UserHistory.actions[:check_personal_message],
        topic_id: topic.id,
        context: topic.relative_url,
      ),
    )
  end

  def log_post_approved(post, opts = {})
    raise Discourse::InvalidParameters.new(:post) unless post.is_a?(Post)
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:post_approved], post_id: post.id),
    )
  end

  def log_post_rejected(reviewable, rejected_at, opts = {})
    raise Discourse::InvalidParameters.new(:rejected_post) unless reviewable.is_a?(Reviewable)

    topic = reviewable.topic || Topic.with_deleted.find_by(id: reviewable.topic_id)
    topic_title = topic&.title || I18n.t("staff_action_logs.not_found")
    username = reviewable.target_created_by&.username || I18n.t("staff_action_logs.unknown")
    name = reviewable.target_created_by&.name || I18n.t("staff_action_logs.unknown")

    details = [
      "created_at: #{reviewable.created_at}",
      "rejected_at: #{rejected_at}",
      "user: #{username} (#{name})",
      "topic: #{topic_title}",
      "raw: #{truncate(reviewable.payload["raw"])}",
    ]

    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:post_rejected], details: details.join("\n")),
    )
  end

  def log_web_hook(web_hook, action, opts = {})
    details = ["webhook_id: #{web_hook.id}", "payload_url: #{web_hook.payload_url}"]

    old_values, new_values = get_changes(opts[:changes])

    UserHistory.create!(
      params(opts).merge(
        action: action,
        context: details.join(", "),
        previous_value: old_values&.join(", "),
        new_value: new_values&.join(", "),
      ),
    )
  end

  def log_web_hook_deactivate(web_hook, response_http_status, opts = {})
    context = ["webhook_id: #{web_hook.id}", "webhook_response_status: #{response_http_status}"]

    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:web_hook_deactivate],
        context: context,
        details:
          I18n.t("staff_action_logs.webhook_deactivation_reason", status: response_http_status),
      ),
    )
  end

  def log_embeddable_host(embeddable_host, action, opts = {})
    old_values, new_values = get_changes(opts[:changes])

    UserHistory.create!(
      params(opts).merge(
        action: action,
        context: "host: #{embeddable_host.host}",
        previous_value: old_values&.join(", "),
        new_value: new_values&.join(", "),
      ),
    )
  end

  def log_api_key(api_key, action, opts = {})
    opts[:changes]&.delete("key") # Do not log the full key

    history_params = params(opts).merge(action: action, subject: api_key.truncated_key)

    if opts[:changes]
      old_values, new_values = get_changes(opts[:changes])
      history_params[:previous_value] = old_values&.join(", ") if opts[:changes].keys.exclude?("id")
      history_params[:new_value] = new_values&.join(", ")
    end

    UserHistory.create!(history_params)
  end

  def log_api_key_revoke(api_key)
    UserHistory.create!(
      params.merge(
        subject: api_key.truncated_key,
        action: UserHistory.actions[:api_key_update],
        details: I18n.t("staff_action_logs.api_key.revoked"),
      ),
    )
  end

  def log_api_key_restore(api_key)
    UserHistory.create!(
      params.merge(
        subject: api_key.truncated_key,
        action: UserHistory.actions[:api_key_update],
        details: I18n.t("staff_action_logs.api_key.restored"),
      ),
    )
  end

  def log_published_page(topic_id, slug)
    UserHistory.create!(
      params.merge(subject: slug, topic_id: topic_id, action: UserHistory.actions[:page_published]),
    )
  end

  def log_unpublished_page(topic_id, slug)
    UserHistory.create!(
      params.merge(
        subject: slug,
        topic_id: topic_id,
        action: UserHistory.actions[:page_unpublished],
      ),
    )
  end

  def log_add_email(user)
    raise Discourse::InvalidParameters.new(:user) unless user

    UserHistory.create!(
      action: UserHistory.actions[:add_email],
      acting_user_id: @admin.id,
      target_user_id: user.id,
    )
  end

  def log_update_email(user)
    raise Discourse::InvalidParameters.new(:user) unless user

    UserHistory.create!(
      action: UserHistory.actions[:update_email],
      acting_user_id: @admin.id,
      target_user_id: user.id,
    )
  end

  def log_destroy_email(user)
    raise Discourse::InvalidParameters.new(:user) unless user

    UserHistory.create!(
      action: UserHistory.actions[:destroy_email],
      acting_user_id: @admin.id,
      target_user_id: user.id,
    )
  end

  def log_watched_words_creation(watched_word)
    raise Discourse::InvalidParameters.new(:watched_word) unless watched_word

    action_key = :watched_word_create
    action_key = :create_watched_word_group if watched_word.is_a?(WatchedWordGroup)

    UserHistory.create!(
      action: UserHistory.actions[action_key],
      acting_user_id: @admin.id,
      details: watched_word.action_log_details,
      context: WatchedWord.actions[watched_word.action],
    )
  end

  def log_watched_words_deletion(watched_word)
    raise Discourse::InvalidParameters.new(:watched_word) unless watched_word

    action_key = :watched_word_destroy
    action_key = :delete_watched_word_group if watched_word.is_a?(WatchedWordGroup)

    UserHistory.create!(
      action: UserHistory.actions[action_key],
      acting_user_id: @admin.id,
      details: watched_word.action_log_details,
      context: WatchedWord.actions[watched_word.action],
    )
  end

  def log_group_deletion(group)
    raise Discourse::InvalidParameters.new(:group) if group.nil?

    details = ["name: #{group.name}", "id: #{group.id}"]

    details << "grant_trust_level: #{group.grant_trust_level}" if group.grant_trust_level

    UserHistory.create!(
      acting_user_id: @admin.id,
      action: UserHistory.actions[:delete_group],
      details: details.join(", "),
    )
  end

  def log_permanently_delete_post_revisions(post)
    raise Discourse::InvalidParameters.new(:post) if post.nil?

    UserHistory.create!(
      action: UserHistory.actions[:permanently_delete_post_revisions],
      acting_user_id: @admin.id,
      post_id: post.id,
    )
  end

  def log_create_public_sidebar_section(section)
    UserHistory.create!(
      action: UserHistory.actions[:create_public_sidebar_section],
      acting_user_id: @admin.id,
      subject: section.title,
      details: custom_section_details(section),
    )
  end

  def log_update_public_sidebar_section(section)
    UserHistory.create!(
      action: UserHistory.actions[:update_public_sidebar_section],
      acting_user_id: @admin.id,
      subject: section.title,
      details: custom_section_details(section),
    )
  end

  def log_destroy_public_sidebar_section(section)
    UserHistory.create!(
      action: UserHistory.actions[:destroy_public_sidebar_section],
      acting_user_id: @admin.id,
      subject: section.title,
    )
  end

  def log_reset_bounce_score(user, opts = {})
    raise Discourse::InvalidParameters.new(:user) unless user

    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:reset_bounce_score], target_user_id: user.id),
    )
  end

  def log_custom_emoji_create(name, opts = {})
    opts[:details] = "Group: #{opts[:group]}" if opts[:group].present?

    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:custom_emoji_create], new_value: name),
    )
  end

  def log_custom_emoji_destroy(name, opts = {})
    UserHistory.create!(
      params(opts).merge(action: UserHistory.actions[:custom_emoji_destroy], previous_value: name),
    )
  end

  def log_tag_group_create(name, new_value, opts = {})
    UserHistory.create!(
      params(opts).merge(json_params(nil, new_value)).merge(
        action: UserHistory.actions[:tag_group_create],
        subject: name,
      ),
    )
  end

  def log_tag_group_destroy(name, old_value, opts = {})
    UserHistory.create!(
      params(opts).merge(json_params(old_value, nil)).merge(
        action: UserHistory.actions[:tag_group_destroy],
        subject: name,
      ),
    )
  end

  def log_tag_group_change(name, old_data, new_data)
    UserHistory.create!(
      params.merge(json_params(old_data, new_data)).merge(
        action: UserHistory.actions[:tag_group_change],
        subject: name,
      ),
    )
  end

  def log_delete_associated_accounts(user, previous_value:, context:)
    UserHistory.create!(
      params.merge(
        action: UserHistory.actions[:delete_associated_accounts],
        target_user_id: user.id,
        previous_value:,
        context:,
      ),
    )
  end

  private

  def json_params(previous_value, new_value)
    if (previous_value && previous_value.length > UserHistory::MAX_JSON_LENGTH) ||
         (new_value && new_value.length > UserHistory::MAX_JSON_LENGTH)
      { context: I18n.t("staff_action_logs.json_too_long") }
    else
      { previous_value: previous_value, new_value: new_value }
    end
  end

  def get_changes(changes)
    return unless changes

    changes.delete("updated_at")
    old_values = []
    new_values = []
    changes
      .sort_by { |k, _| k.to_s }
      .each do |k, v|
        old_values << "#{k}: #{v[0]}"
        new_values << "#{k}: #{v[1]}"
      end

    [old_values, new_values]
  end

  def params(opts = nil)
    opts ||= {}
    { acting_user_id: @admin.id, context: opts[:context], details: opts[:details] }
  end

  def validate_category(category)
    raise Discourse::InvalidParameters.new(:category) unless category && category.is_a?(Category)
  end

  def custom_section_details(section)
    urls = section.sidebar_urls.map { |url| "#{url.name} - #{url.value}" }
    "links: #{urls.join(", ")}"
  end

  def truncate(s)
    if s.size > UserHistory::MAX_CONTEXT_LENGTH
      "#{s.slice(..UserHistory::MAX_CONTEXT_LENGTH)}..."
    else
      s
    end
  end
end
