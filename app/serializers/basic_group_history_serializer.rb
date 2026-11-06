# frozen_string_literal: true

class BasicGroupHistorySerializer < ApplicationSerializer
  RESTRICTED_SUBJECT_AUDIENCES = {
    "incoming_email" => :staff,
    "automatic_membership_email_domains" => :group_admin,
    "email_password" => :admin,
    "email_username" => :admin,
    "email_from_alias" => :admin,
    "smtp_server" => :admin,
    "smtp_port" => :admin,
    "smtp_ssl_mode" => :admin,
    "smtp_enabled" => :admin,
    "smtp_updated_at" => :admin,
    "smtp_updated_by_id" => :admin,
    "allow_unknown_sender_topic_replies" => :admin,
  }.freeze
  private_constant :RESTRICTED_SUBJECT_AUDIENCES

  attributes :action, :subject, :prev_value, :new_value, :created_at

  has_one :acting_user, embed: :objects, serializer: BasicUserSerializer
  has_one :target_user, embed: :objects, serializer: BasicUserSerializer

  def action
    GroupHistory.actions[object.action]
  end

  def prev_value
    redact_setting_value(object.prev_value)
  end

  def new_value
    redact_setting_value(object.new_value)
  end

  private

  def redact_setting_value(value)
    return value if value.blank?
    return value if !RESTRICTED_SUBJECT_AUDIENCES.key?(object.subject)

    authorized =
      case RESTRICTED_SUBJECT_AUDIENCES[object.subject]
      when :staff
        scope&.is_staff?
      when :admin
        scope&.is_admin?
      when :group_admin
        scope&.can_admin_group?(object.group)
      end
    return value if authorized

    I18n.t("staff_action_logs.redacted")
  end
end
