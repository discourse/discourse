class Admin::EmailTemplatesController < Admin::AdminController

  def self.email_keys
    @email_keys ||= ["invite_forum_mailer", "invite_mailer", "invite_password_instructions",
                     "new_version_mailer", "new_version_mailer_with_notes", "queued_posts_reminder",
                     "system_messages.backup_failed", "system_messages.backup_succeeded",
                     "system_messages.blocked_by_staff", "system_messages.bulk_invite_failed",
                     "system_messages.bulk_invite_succeeded", "system_messages.csv_export_failed",
                     "system_messages.csv_export_succeeded", "system_messages.download_remote_images_disabled",
                     "system_messages.email_error_notification", "system_messages.email_reject_auto_generated",
                     "system_messages.email_reject_destination", "system_messages.email_reject_empty",
                     "system_messages.email_reject_invalid_access", "system_messages.email_reject_no_account",
                     "system_messages.email_reject_parsing", "system_messages.email_reject_post_error",
                     "system_messages.email_reject_post_error_specified", "system_messages.email_reject_user_not_found",
                     "system_messages.email_reject_reply_key", "system_messages.email_reject_topic_closed",
                     "system_messages.email_reject_topic_not_found", "system_messages.email_reject_trust_level",
                     "system_messages.email_reject_screened_email",
                     "system_messages.pending_users_reminder", "system_messages.post_hidden",
                     "system_messages.restore_failed", "system_messages.restore_succeeded",
                     "system_messages.spam_post_blocked", "system_messages.too_many_spam_flags",
                     "system_messages.unblocked", "system_messages.user_automatically_blocked",
                     "system_messages.welcome_invite", "system_messages.welcome_user", "test_mailer",
                     "user_notifications.account_created", "user_notifications.admin_login",
                     "user_notifications.confirm_new_email", "user_notifications.confirm_old_email",
                     "user_notifications.notify_old_email", "user_notifications.forgot_password",
                     "user_notifications.set_password", "user_notifications.signup",
                     "user_notifications.signup_after_approval",
                     "user_notifications.user_invited_to_private_message_pm",
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

    TranslationOverride.upsert!(I18n.locale, "#{key}.subject_template", et[:subject])
    TranslationOverride.upsert!(I18n.locale, "#{key}.text_body_template", et[:body])

    render_serialized(key, AdminEmailTemplateSerializer, root: 'email_template', rest_serializer: true)
  end

  def revert
    key = params[:id]
    raise Discourse::NotFound unless self.class.email_keys.include?(params[:id])
    TranslationOverride.revert!(I18n.locale, "#{key}.subject_template", "#{key}.text_body_template")
    render_serialized(key, AdminEmailTemplateSerializer, root: 'email_template', rest_serializer: true)
  end

  def index
    render_serialized(self.class.email_keys, AdminEmailTemplateSerializer, root: 'email_templates', rest_serializer: true)
  end

end
