# frozen_string_literal: true

class BasicGroupHistorySerializer < ApplicationSerializer
  GROUP_OWNER_ALLOWED_SUBJECTS = %w[
    automatic
    name
    mentionable_level
    messageable_level
    visibility_level
    primary_group
    title
    grant_trust_level
    flair_upload_id
    flair_icon
    flair_bg_color
    flair_color
    bio_raw
    public_admission
    public_exit
    allow_membership_requests
    full_name
    default_notification_level
    membership_request_template
    members_visibility_level
    publish_read_state
  ].freeze
  private_constant :GROUP_OWNER_ALLOWED_SUBJECTS

  STAFF_ALLOWED_SUBJECTS = (GROUP_OWNER_ALLOWED_SUBJECTS + %w[incoming_email has_messages]).freeze
  private_constant :STAFF_ALLOWED_SUBJECTS

  GROUP_MANAGING_MODERATOR_ALLOWED_SUBJECTS =
    (STAFF_ALLOWED_SUBJECTS + %w[automatic_membership_email_domains]).freeze
  private_constant :GROUP_MANAGING_MODERATOR_ALLOWED_SUBJECTS

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
    return value if value.blank? || scope&.is_admin?

    allowed_subjects =
      if scope&.can_admin_group?(object.group, is_group_owner: @options[:is_group_owner])
        GROUP_MANAGING_MODERATOR_ALLOWED_SUBJECTS
      elsif scope&.is_staff?
        STAFF_ALLOWED_SUBJECTS
      elsif scope&.can_edit_group?(object.group, is_group_owner: @options[:is_group_owner])
        GROUP_OWNER_ALLOWED_SUBJECTS
      else
        []
      end

    return value if allowed_subjects.include?(object.subject)

    I18n.t("staff_action_logs.redacted")
  end
end
