# frozen_string_literal: true

class UserHistorySerializer < ApplicationSerializer
  # Names are interpolated unescaped, so they can span lines or contain field labels.
  # A deleted user's name runs to the last `created_at:`, and deletions logged before
  # late 2014 joined fields with ", ". The author pattern is anchored to the header so
  # quoted text in a post body is never rewritten.
  DELETED_USER_NAME = /^name: .*\n(?=created_at: )|, name: .*(?=, created_at: )/m
  POST_AUTHOR_NAME =
    /\A(?:id: [^\n]*\n)?created_at: [^\n]*\n(?:rejected_at: [^\n]*\n)?user: \S+\K \(.*?\)(?=\n(?:topic|title|raw): )/m

  NAME_IN_DETAILS =
    {
      delete_user: DELETED_USER_NAME,
      delete_post: POST_AUTHOR_NAME,
      delete_topic: POST_AUTHOR_NAME,
      recover_post: POST_AUTHOR_NAME,
      recover_topic: POST_AUTHOR_NAME,
      post_rejected: POST_AUTHOR_NAME,
    }.transform_keys { |action| UserHistory.actions[action] }.freeze

  attributes :action_name,
             :details,
             :context,
             :ip_address,
             :email,
             :created_at,
             :expires_at,
             :subject,
             :previous_value,
             :new_value,
             :topic_id,
             :post_id,
             :category_id,
             :reviewable_id,
             :action,
             :custom_type,
             :id

  has_one :acting_user, serializer: BasicUserSerializer, embed: :objects
  has_one :target_user, serializer: BasicUserSerializer, embed: :objects

  def action_name
    key = UserHistory.actions.key(object.action)
    %i[custom custom_staff].include?(key) ? object.custom_type : key.to_s
  end

  def details
    return redacted_content if redact_content?

    name_pattern = NAME_IN_DETAILS[object.action] if redact_user_names?
    name_pattern ? object.details&.sub(name_pattern, "") : object.details
  end

  def context
    redact_content? ? nil : object.context
  end

  def expires_at
    redact_content? ? nil : object.expires_at
  end

  def new_value
    return nil if redact_content? || redact_name_change?
    if object.new_value
      object.new_value_is_json? ? ::JSON.parse(object.new_value) : object.new_value
    else
      nil
    end
  end

  def previous_value
    return nil if redact_content? || redact_name_change?
    if object.previous_value
      object.previous_value_is_json? ? ::JSON.parse(object.previous_value) : object.previous_value
    else
      nil
    end
  end

  def ip_address
    return nil unless scope.can_see_ip?
    object.ip_address.try(:to_s)
  end

  def include_reviewable_id?
    object.reviewable_id.present?
  end

  private

  def redact_name_change?
    redact_user_names? && object.action == UserHistory.actions[:change_name]
  end

  def redact_user_names?
    !SiteSetting.enable_names? && !scope.is_admin?
  end

  def redact_content?
    return @redact_content if defined?(@redact_content)
    @redact_content = !scope.can_see_staff_action_log_content?(object)
  end

  def redacted_content
    I18n.t("staff_action_logs.redacted")
  end
end
