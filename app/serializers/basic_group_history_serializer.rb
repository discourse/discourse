# frozen_string_literal: true

class BasicGroupHistorySerializer < ApplicationSerializer
  STAFF_ONLY_SUBJECTS = %w[incoming_email].freeze
  ADMIN_ONLY_SUBJECTS = %w[
    email_password
    email_username
    email_from_alias
    smtp_server
    smtp_port
    smtp_ssl_mode
    smtp_enabled
    smtp_updated_at
    smtp_updated_by_id
    allow_unknown_sender_topic_replies
  ].freeze
  GROUP_ADMIN_ONLY_SUBJECTS = %w[automatic_membership_email_domains].freeze
  private_constant :STAFF_ONLY_SUBJECTS, :ADMIN_ONLY_SUBJECTS, :GROUP_ADMIN_ONLY_SUBJECTS

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

    if STAFF_ONLY_SUBJECTS.include?(object.subject)
      return value if scope&.is_staff?
    elsif ADMIN_ONLY_SUBJECTS.include?(object.subject)
      return value if scope&.is_admin?
    elsif GROUP_ADMIN_ONLY_SUBJECTS.include?(object.subject)
      return value if scope&.can_admin_group?(object.group)
    else
      return value
    end

    I18n.t("staff_action_logs.redacted")
  end
end
