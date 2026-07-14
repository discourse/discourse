# frozen_string_literal: true

class BasicGroupHistorySerializer < ApplicationSerializer
  EMAIL_SETTING_SUBJECTS =
    Set.new(%w[email_password email_username smtp_server smtp_port smtp_ssl_mode])

  attributes :action, :subject, :prev_value, :new_value, :created_at

  has_one :acting_user, embed: :objects, serializer: BasicUserSerializer
  has_one :target_user, embed: :objects, serializer: BasicUserSerializer

  def action
    GroupHistory.actions[object.action]
  end

  def prev_value
    redact_email_setting_value(object.prev_value)
  end

  def new_value
    redact_email_setting_value(object.new_value)
  end

  private

  def redact_email_setting_value(value)
    return value if value.blank?
    return value if !EMAIL_SETTING_SUBJECTS.include?(object.subject)
    return value if scope&.can_admin_group?(object.group)

    I18n.t("staff_action_logs.redacted")
  end
end
