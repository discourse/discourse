class Admin::EmailTemplatesController < Admin::AdminController

  def self.email_keys
    @email_keys ||= ["invite_forum_mailer", "invite_mailer", "invite_password_instructions",
                     "custom_invite_mailer", "custom_invite_forum_mailer",
                     "new_version_mailer", "new_version_mailer_with_notes", "queued_posts_reminder",
                     "system_messages.backup_failed", "system_messages.backup_succeeded",
                     "system_messages.silenced_by_staff", "system_messages.bulk_invite_failed",
                     "system_messages.bulk_invite_succeeded", "system_messages.csv_export_failed",
                     "system_messages.csv_export_succeeded", "system_messages.download_remote_images_disabled",
                     "system_messages.email_error_notification", "system_messages.email_reject_auto_generated",
                     "system_messages.email_reject_empty",
                     "system_messages.email_reject_invalid_access", "system_messages.email_reject_no_account",
                     "system_messages.email_reject_parsing", "system_messages.email_reject_user_not_found",
                     "system_messages.email_reject_reply_key", "system_messages.email_reject_topic_closed",
                     "system_messages.email_reject_topic_not_found",
                     "system_messages.email_reject_screened_email",
                     "system_messages.email_reject_unrecognized_error",
                     "system_messages.pending_users_reminder", "system_messages.post_hidden",
                     "system_messages.post_hidden_again",
                     "system_messages.restore_failed", "system_messages.restore_succeeded",
                     "system_messages.spam_post_blocked", "system_messages.too_many_spam_flags",
                     "system_messages.unsilenced", "system_messages.user_automatically_silenced",
                     "system_messages.welcome_invite", "system_messages.welcome_user", "test_mailer",
                     "user_notifications.account_created", "user_notifications.admin_login",
                     "user_notifications.confirm_new_email",
                     "user_notifications.notify_old_email", "user_notifications.forgot_password",
                     "user_notifications.set_password", "user_notifications.signup",
                     "user_notifications.signup_after_approval",
                     "user_notifications.user_invited_to_private_message_pm",
                     "user_notifications.user_invited_to_private_message_pm_group",
                     "user_notifications.user_invited_to_topic", "user_notifications.user_mentioned",
                     "user_notifications.user_posted", "user_notifications.user_posted_pm",
                     "user_notifications.user_quoted", "user_notifications.user_replied",
                     "user_notifications.user_linked"]
  end

  def show
  end

  def update
    et = params[:email_template]
    key = params[:id]
    raise Discourse::NotFound unless self.class.email_keys.include?(params[:id])

    subject_result = update_key("#{key}.subject_template", et[:subject])
    body_result = update_key("#{key}.text_body_template", et[:body])

    error_messages = []
    if subject_result[:error_messages].present?
      error_messages << format_error_message(subject_result, "subject")
    end
    if body_result[:error_messages].present?
      error_messages << format_error_message(body_result, "body")
    end

    if error_messages.blank?
      log_site_text_change(subject_result)
      log_site_text_change(body_result)

      render_serialized(key, AdminEmailTemplateSerializer, root: 'email_template', rest_serializer: true)
    else
      TranslationOverride.upsert!(I18n.locale, "#{key}.subject_template", subject_result[:old_value])
      TranslationOverride.upsert!(I18n.locale, "#{key}.text_body_template", body_result[:old_value])

      render_json_error(error_messages)
    end
  end

  def revert
    key = params[:id]
    raise Discourse::NotFound unless self.class.email_keys.include?(params[:id])

    revert_and_log("#{key}.subject_template", "#{key}.text_body_template")
    render_serialized(key, AdminEmailTemplateSerializer, root: 'email_template', rest_serializer: true)
  end

  def index
    render_serialized(self.class.email_keys, AdminEmailTemplateSerializer, root: 'email_templates', rest_serializer: true)
  end

  private

  def update_key(key, value)
    old_value = I18n.t(key)
    translation_override = TranslationOverride.upsert!(I18n.locale, key, value)

    {
      key: key,
      old_value: old_value,
      error_messages: translation_override.errors.full_messages
    }
  end

  def revert_and_log(*keys)
    old_values = {}
    keys.each { |key| old_values[key] = I18n.t(key) }

    TranslationOverride.revert!(I18n.locale, keys)

    keys.each do |key|
      old_value = old_values[key]
      new_value = I18n.t(key)
      StaffActionLogger.new(current_user).log_site_text_change(key, new_value, old_value)
    end
  end

  def log_site_text_change(update_result)
    new_value = I18n.t(update_result[:key])
    StaffActionLogger.new(current_user).log_site_text_change(
      update_result[:key], new_value, update_result[:old_value])
  end

  def format_error_message(update_result, attribute_key)
    attribute = I18n.t("admin_js.admin.customize.email_templates.#{attribute_key}")
    message = update_result[:error_messages].join("<br>")
    I18n.t("errors.format_with_full_message", attribute: attribute, message: message)
  end
end
