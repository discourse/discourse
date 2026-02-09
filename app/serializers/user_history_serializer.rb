# frozen_string_literal: true

class UserHistorySerializer < ApplicationSerializer
  attributes :action_name,
             :details,
             :context,
             :ip_address,
             :email,
             :created_at,
             :subject,
             :previous_value,
             :new_value,
             :topic_id,
             :post_id,
             :category_id,
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
    redact_content? ? redacted_content : object.details
  end

  def context
    redact_content? ? nil : object.context
  end

  def new_value
    return nil if redact_content?
    if object.new_value
      object.new_value_is_json? ? ::JSON.parse(object.new_value) : object.new_value
    else
      nil
    end
  end

  def previous_value
    return nil if redact_content?
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

  private

  def redact_content?
    return @redact_content if defined?(@redact_content)
    @redact_content = !scope.can_see_staff_action_log_content?(object)
  end

  def redacted_content
    I18n.t("staff_action_logs.redacted")
  end
end
