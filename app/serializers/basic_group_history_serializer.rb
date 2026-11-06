# frozen_string_literal: true

class BasicGroupHistorySerializer < ApplicationSerializer
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
    return value if scope && readable_group_fields.include?(object.subject)

    I18n.t("staff_action_logs.redacted")
  end

  def readable_group_fields
    @readable_group_fields ||=
      @options[:readable_group_fields] ||
        GroupShowSerializer.new(
          object.group,
          scope: scope,
          for_group_history: true,
        ).readable_group_fields
  end
end
